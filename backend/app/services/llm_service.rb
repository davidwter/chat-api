# app/services/llm_service.rb
class LlmService
  include HTTParty
  base_uri ENV.fetch('OLLAMA_HOST', 'http://ollama:11434')
  default_timeout 120  # 2 minutes total timeout

  RETRY_COUNT = 2
  RETRY_DELAY = 1  # seconds

  class << self
    def generate_response(prompt, retries: RETRY_COUNT)
      with_timing do
        # First pass: identify relevant connectors
        Rails.logger.info("Starting connector identification...")
        connector_names = identify_relevant_connectors(prompt)
        Rails.logger.info("Identified connectors: #{connector_names.join(', ')}")

        # Extract integration requirements
        Rails.logger.info("Analyzing integration requirements...")
        requirements = extract_integration_requirements(prompt, connector_names)

        # If we have exactly two connectors, analyze feasibility
        if connector_names.size == 2
          Rails.logger.info("Analyzing integration feasibility...")
          feasibility = ConnectorCapabilityService.verify_integration_feasibility(
            connector_names[0],
            connector_names[1],
            requirements
          )
        end

        # Get capabilities context
        Rails.logger.info("Fetching capabilities...")
        capabilities = ConnectorCapabilityService.get_capabilities(connector_names)
        capabilities_context = ConnectorCapabilityService.format_capabilities_for_llm(capabilities)

        # Final response with enhanced context
        Rails.logger.info("Generating detailed response...")
        generate_detailed_response(prompt, {
          capabilities_context: capabilities_context,
          feasibility: feasibility,
          requirements: requirements
        })
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      handle_timeout_error(e, prompt, retries)
    rescue => e
      Rails.logger.error("Unexpected error in generate_response:")
      Rails.logger.error("Error class: #{e.class}")
      Rails.logger.error("Error message: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")

      handle_general_error(e, prompt, retries)
  end


    def extract_integration_requirements(prompt, connector_names)
      return {} unless connector_names.size == 2

      # Early validation
      if connector_names.any?(&:nil?)
        Rails.logger.error("Nil connector name provided")
        return { source: { triggers: [], actions: [] }, target: { triggers: [], actions: [] } }
      end

      # Fetch predefined capabilities first
      begin
        connector_capabilities = ConnectorCapabilityService.get_capabilities(connector_names)
      rescue => e
        Rails.logger.error("Failed to fetch connector capabilities: #{e.message}")
        connector_capabilities = []
      end

      # Prepare a more structured system context with existing capabilities
      system_context = <<~PROMPT
    You are an advanced integration assistant for Workato. 

    Available Connectors and Their Capabilities:
    #{connector_capabilities.map { |c|
        "#{c[:name]}:\n" +
          "Triggers: #{c[:triggers]&.map { |t| t[:name] }&.join(', ') || 'None'}\n" +
          "Actions: #{c[:actions]&.map { |a| a[:name] }&.join(', ') || 'None'}"
      }.join("\n\n")}

    Given the user's request, ONLY return a JSON with:
    1. Most relevant trigger from source
    2. Most relevant action for target
    3. Brief rationale

    Requirements:
    - Use ONLY triggers/actions listed above
    - Keep response extremely concise
    - Return valid JSON
  PROMPT

      # Multiple fallback responses
      fallback_responses = [
        "{\"source\":{\"triggers\":[],\"actions\":[]},\"target\":{\"triggers\":[],\"actions\":[]}}",
        "{\"source\":{\"triggers\":[\"default_trigger\"],\"actions\":[\"default_action\"]},\"target\":{\"triggers\":[\"default_trigger\"],\"actions\":[\"default_action\"]}}",
        "{}"
      ]

      # Retry mechanism with exponential backoff
      [30, 60, 120].each do |timeout|
        begin
          Timeout.timeout(timeout) do
            # Defensive call to LLM
            response = begin
                         call_llm(system_context, prompt,
                                  short_response: true,
                                  timeout: timeout)
                       rescue => e
                         Rails.logger.error("LLM call failed: #{e.message}")
                         nil
                       end

            # Ensure response is not nil
            if response.nil?
              Rails.logger.warn("Received nil response from LLM")
              next  # Try next timeout
            end

            # Multiple parsing strategies
            parsed_response = begin
                                # Try direct JSON parsing
                                JSON.parse(response)
                              rescue JSON::ParserError
                                # Try extracting JSON-like content
                                json_match = response.match(/\{.*\}/m)
                                json_match ? JSON.parse(json_match[0]) : nil
                              rescue => e
                                Rails.logger.warn("JSON parsing failed: #{e.message}")
                                Rails.logger.debug("Problematic response: #{response}")
                                nil
                              end

            # Return parsed response if valid
            return parsed_response if parsed_response.is_a?(Hash)
          end
        rescue Timeout::Error => e
          Rails.logger.warn("Timeout at #{timeout} seconds: #{e.message}")

          # Return a fallback response
          return JSON.parse(fallback_responses.sample) if fallback_responses.any?
        rescue => e
          Rails.logger.error("Unexpected error in extract_integration_requirements: #{e.message}")
          Rails.logger.error("Error details: #{e.backtrace.join("\n")}")
        end
      end

      # Ultimate fallback
      {
        source: { triggers: [], actions: [] },
        target: { triggers: [], actions: [] }
      }
    end

    private

    def with_timing
      start_time = Time.now
      result = yield
      duration = Time.now - start_time
      Rails.logger.info("LLM request completed in #{duration.round(2)} seconds")
      result
    end

    def identify_relevant_connectors(prompt)
      available_connectors = Connector.pluck(:name).join(", ")

      system_context = <<~PROMPT
        You are an integration assistant. Given a user's request, identify which connectors 
        are relevant. Return ONLY a JSON array of connector names, no other text.
        
        Available connectors:
        #{available_connectors}
      PROMPT

      response = call_llm(system_context, prompt,
                          short_response: true,
                          timeout: 30)

      begin
        JSON.parse(response)
      rescue JSON::ParserError
        response.scan(/\"(.*?)\"/).flatten.uniq
      end
    end



    def generate_detailed_response(prompt, context)
      capabilities_context = context[:capabilities_context]
      feasibility = context[:feasibility]
      requirements = context[:requirements]

      # Create different system contexts based on feasibility analysis
      system_context = if feasibility
                         create_feasibility_context(feasibility, capabilities_context)
                       else
                         create_basic_context(capabilities_context)
                       end

      response = call_llm(system_context, prompt, timeout: 90)
      format_response(response)
    end

    def create_feasibility_context(feasibility, capabilities_context)
      feasibility_score = feasibility[:feasibility][:score]
      constraints = feasibility[:feasibility][:constraints]
      missing_capabilities = feasibility[:missing_capabilities]

      <<~PROMPT
        You are an integration assistant specifically for the Workato iPaaS platform.
        
        Current integration analysis:
        - Feasibility Score: #{feasibility_score}/100
        - Technical Constraints: #{constraints.map { |c| c[:details] }.flatten.join(', ')}
        - Missing Capabilities: #{format_missing_capabilities(missing_capabilities)}
        
        Available connector details:
        #{capabilities_context}
        
        Format your response with these exact sections:
        1. Technical Feasibility Assessment:
           - State if the integration is feasible (score > 60 means feasible)
           - List key technical constraints
           - Explain missing capabilities impact

        2. Required Connectors:
           - List involved connectors (use ** for names)
           - Include their main purpose in this integration

        3. Integration Blueprint:
           - List required triggers and actions
           - Note any missing capabilities
           - Suggest workarounds for limitations

        4. Enhancement Recommendations:
           - List suggested connector improvements
           - Prioritize critical missing features
           - Suggest alternative approaches if needed

        Use these formatting rules:
        - Use double asterisks for connector names (e.g., **Slack**)
        - Use bullet points (•) for lists
        - Reference exact trigger and action names
        - Mention only Workato-specific features
      PROMPT
    end

    def create_basic_context(capabilities_context)
      <<~PROMPT
        You are an integration assistant specifically for the Workato iPaaS platform.
        
        Available connector details:
        #{capabilities_context}
        
        Format your response with these exact sections:
        1. Required Connectors:
           - List connectors needed (use ** for names)
           - Explain their role in the integration

        2. Integration Design:
           - Describe the suggested approach
           - List potential triggers and actions
           - Note any potential limitations

        3. Recommendations:
           - Suggest best practices
           - Note any considerations
           - Provide alternative approaches if relevant

        Use these formatting rules:
        - Use double asterisks for connector names (e.g., **Slack**)
        - Use bullet points (•) for lists
        - Use exact trigger and action names when available
        - Focus on Workato-specific features
      PROMPT
    end

    def format_missing_capabilities(missing_capabilities)
      return "None identified" unless missing_capabilities

      source = missing_capabilities[:source]
      target = missing_capabilities[:target]

      missing = []
      missing << "Source: #{format_missing_items(source)}" if source&.any?
      missing << "Target: #{format_missing_items(target)}" if target&.any?

      missing.empty? ? "None identified" : missing.join("; ")
    end

    def format_missing_items(items)
      return "None" unless items&.any?

      "#{items[:triggers]&.join(', ')} #{items[:actions]&.join(', ')}".strip
    end

    def format_response(response)
      # Clean up the raw text
      formatted = response.gsub(/\n{2,}/, '\n') # Reduce multiple newlines
      formatted = formatted.gsub(/\s{2,}/, ' ')  # Clean up excessive spaces
      formatted = formatted.gsub(/\*\s+\*/, '**') # Fix separated asterisks

      # Add newlines for sections
      formatted = formatted.gsub(
        /(\d+\.\s*)(Technical Feasibility Assessment:|Required Connectors:|Integration Blueprint:|Enhancement Recommendations:|Integration Design:|Recommendations:)/,
        '\n\1\2'
      )

      # Format sub-points
      formatted = formatted.gsub(/([.!?])\s+(\d+\.\s)/, '\1\n\2')
      formatted = formatted.gsub(/([.!?])\s+(\•\s)/, '\1\n\2')

      formatted.strip
    end

    def call_llm(system_context, prompt, short_response: false, timeout: 90)
      options = if short_response
                  {
                    temperature: 0.3,
                    top_k: 10,
                    top_p: 0.8,
                    num_predict: 100,
                    stop: ["\n", "User:"],
                    num_ctx: 1024,
                    num_thread: 4
                  }
                else
                  {
                    temperature: 0.7,
                    top_k: 40,
                    top_p: 0.9,
                    num_predict: 750,
                    stop: ["User:", "\n\n\n"],
                    num_ctx: 2048,
                    num_thread: 8
                  }
                end

      full_prompt = "#{system_context}\n\nUser: #{prompt}"
      Rails.logger.info("Making LLM request with timeout: #{timeout}s")

      response = post("/api/generate",
                      body: {
                        model: "mistral",
                        prompt: full_prompt,
                        stream: false,
                        options: options
                      }.to_json,
                      headers: { 'Content-Type' => 'application/json' },
                      timeout: timeout
      )

      if response.success?
        response.parsed_response["response"]
      else
        Rails.logger.error("LLM Error: #{response.code} - #{response.body}")
        raise "Failed to generate response: #{response.code}"
      end
    end

    def handle_timeout_error(error, prompt, retries)
      if retries > 0
        Rails.logger.warn("Timeout occurred. Retrying... (#{retries} attempts left)")
        sleep(RETRY_DELAY)
        generate_response(prompt, retries: retries - 1)
      else
        Rails.logger.error("Final timeout error: #{error.message}")
        raise "Request timed out after multiple attempts. Please try again."
      end
    end

    def handle_general_error(error, prompt, retries)
      if retries > 0
        Rails.logger.warn("Error occurred. Retrying... (#{retries} attempts left)")
        sleep(RETRY_DELAY)
        generate_response(prompt, retries: retries - 1)
      else
        error_message = error.respond_to?(:message) ? error.message : "Unknown error"
        Rails.logger.error("Final error: #{error.message}")
        full_error_message = "Failed to generate response after multiple attempts. " \
          "Original error: #{error_message || 'No details available'}"

        raise full_error_message

      end
    end

  end
end