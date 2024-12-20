# app/services/llm_service.rb
class LlmService
  include HTTParty
  base_uri ENV.fetch('OLLAMA_HOST', 'http://ollama:11434')
  default_timeout 120  # 2 minutes total timeout

  RETRY_COUNT = 2
  RETRY_DELAY = 1  # seconds

  class << self

    def generate_recipe(prompt, source_caps, target_caps, requirements, feasibility)
      # Create recipe generation context
      system_context = create_recipe_context(source_caps, target_caps, requirements, feasibility)

      # Call LLM with recipe-specific parameters
      response = call_llm(
        system_context,
        prompt,
        timeout: 120,
        llm_options: {
          temperature: 0.4,  # Lower temperature for more focused outputs
          top_k: 30,
          top_p: 0.9,
          num_predict: 1000,  # Longer response for detailed recipe
          stop: ["User:", "\n\n\n"],
          num_ctx: 4096,  # Larger context for complex recipes
          num_thread: 8
        }
      )

      format_recipe_response(response)
    end

    def generate_response(prompt, detected_mentions, retries: RETRY_COUNT)
      with_timing do
        # Extract connector names from detected mentions
        Rails.logger.info("Processing detected mentions...")
        connector_names = detected_mentions.map { |mention| mention[:connector].name }
        Rails.logger.info("Using connectors from mentions: #{connector_names.join(', ')}")

        # Extract integration requirements
        Rails.logger.info("Analyzing integration requirements...")
        requirements = extract_integration_requirements(prompt, connector_names)

        # Create response with basic context
        Rails.logger.info("Generating detailed response...")
        return generate_detailed_response(prompt, {
          capabilities_context: simple_capabilities_context(connector_names),
          feasibility: nil,
          requirements: requirements
        })
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      handle_timeout_error(e, prompt, detected_mentions, retries)
    rescue => e
      Rails.logger.error("Unexpected error in generate_response:")
      Rails.logger.error("Error class: #{e.class}")
      Rails.logger.error("Error message: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      handle_general_error(e, prompt, detected_mentions, retries)
    end


    def extract_integration_requirements(prompt, connector_names)
      return {} unless connector_names.size == 2

      # Early validation
      if connector_names.any?(&:nil?)
        Rails.logger.error("Nil connector name provided")
        return { source: { triggers: [], actions: [] }, target: { triggers: [], actions: [] } }
      end

      # Fetch predefined capabilities
      begin
        connector_capabilities = ConnectorCapabilityService.get_capabilities(connector_names)
      rescue => e
        Rails.logger.error("Failed to fetch connector capabilities: #{e.message}")
        connector_capabilities = []
      end

      # Prepare system context
      system_context = create_requirements_context(connector_capabilities)

      # Try to get response with exponential backoff
      [30, 60, 120].each do |timeout|
        begin
          Timeout.timeout(timeout) do
            response = call_llm(system_context, prompt, short_response: true, timeout: timeout)
            return parse_requirements_response(response) if response
          end
        rescue => e
          Rails.logger.warn("Attempt failed with timeout #{timeout}s: #{e.message}")
        end
      end

      # Ultimate fallback
      {
        source: { triggers: [], actions: [] },
        target: { triggers: [], actions: [] }
      }
    end


    private

    def create_recipe_context(source_caps, target_caps, requirements, feasibility)
      # Format capabilities for better prompting
      source_triggers = format_capabilities(source_caps[:triggers], "trigger")
      target_actions = format_capabilities(target_caps[:actions], "action")

      # Include feasibility analysis in context
      feasibility_context = format_feasibility_context(feasibility)

      <<~PROMPT
        You are a Workato recipe design expert. Create a detailed recipe using these components:

        SOURCE CONNECTOR: #{source_caps[:name]}
        Available Triggers:
        #{source_triggers}

        TARGET CONNECTOR: #{target_caps[:name]}
        Available Actions:
        #{target_actions}

        #{feasibility_context}

        Required capabilities:
        Source: #{requirements.dig(:source, :triggers)&.join(', ')}
        Target: #{requirements.dig(:target, :actions)&.join(', ')}

        Format your response as follows:

        # Recipe Overview
        [Brief description of what this recipe does and its business value]

        # Trigger Configuration
        [Specify the exact trigger to use and its configuration details]

        # Data Mapping
        [List key data mappings between source and target]

        # Main Steps
        1. [First step with specific action]
        2. [Second step]
        [Continue with all necessary steps]

        # Error Handling
        [Specify error handling approach]
        
        # Testing Guidelines
        [Basic testing steps]

        Guidelines:
        - Use only the listed triggers and actions
        - Include specific field mappings
        - Reference exact trigger/action names
        - Include error handling for common scenarios
        - Keep steps clear and actionable
        - Focus on Workato's native capabilities
      PROMPT
    end

    def format_capabilities(capabilities, type)
      capabilities.map do |cap|
        badge = cap[:feature_attributes]["badge"] ? " (#{cap[:feature_attributes]["badge"]})" : ""
        "- #{cap[:name]}#{badge}: #{cap[:description]}"
      end.join("\n")
    end

    def format_feasibility_context(feasibility)
      return "" unless feasibility

      <<~CONTEXT
        Integration Feasibility:
        - Score: #{feasibility[:feasibility][:score]}/100
        - Status: #{feasibility[:feasibility][:is_feasible] ? 'Feasible' : 'May need adjustments'}
        #{format_constraints(feasibility[:feasibility][:constraints])}
      CONTEXT
    end

    def format_constraints(constraints)
      return "" unless constraints&.any?

      "Constraints:\n" + constraints.map { |c| "- #{c[:details].join(', ')}" }.join("\n")
    end

    def format_recipe_response(response)
      return "" unless response

      # Clean up the raw text
      response.gsub(/\n{3,}/, "\n\n")
              .gsub(/\s{2,}/, ' ')
              .gsub(/(?<=[.!?])\s+(?=[A-Z])/, "\n")
              .strip
    end

    def with_timing
      start_time = Time.now
      result = yield
      duration = Time.now - start_time
      Rails.logger.info("LLM request completed in #{duration.round(2)} seconds")
      result
    end

    def generate_detailed_response(prompt, context)
      capabilities_context = context[:capabilities_context]
      feasibility = context[:feasibility]

      # Create context based on feasibility analysis
      system_context = if feasibility
                         create_feasibility_context(feasibility, capabilities_context)
                       else
                         create_basic_context(capabilities_context)
                       end

      response = call_llm(system_context, prompt, timeout: 90)
      format_response(response)
    end

    def create_requirements_context(connector_capabilities)
      capabilities_text = connector_capabilities.map do |c|
        [
          "#{c[:name]}:",
          "Available Triggers: #{c[:triggers]&.map { |t| t[:name] }&.join(', ') || 'None'}",
          "Available Actions: #{c[:actions]&.map { |a| a[:name] }&.join(', ') || 'None'}"
        ].join("\n")
      end.join("\n\n")

      <<~PROMPT
        You are a Workato recipe design assistant. Focus on creating native Workato integrations using the following connectors:
        
        #{capabilities_text}

        Instructions:
        - Return a JSON with source trigger and target action components
        - Only use triggers and actions from the available lists
        - Each response should focus on a single Workato recipe design

        Remember:
        - Always use native Workato connectors and terminology
        - Recipes consist of triggers and actions
        - Authentication is handled through Workato's connection manager
      PROMPT
    end


    def create_feasibility_context(feasibility, capabilities_context)
      feasibility_score = feasibility[:feasibility][:score]
      constraints = feasibility[:feasibility][:constraints]
      missing_capabilities = feasibility[:missing_capabilities]

      <<~PROMPT
        You are a Workato recipe design assistant. Analyze this integration request based on:

        Technical Feasibility Score: #{feasibility_score}/100
        #{constraints.any? ? "Implementation Constraints: #{constraints.map { |c| c[:details] }.flatten.join(', ')}" : ""}
        #{missing_capabilities ? "Missing Capabilities: #{format_missing_capabilities(missing_capabilities)}" : ""}

        Available Connectors and Capabilities:
        #{capabilities_context}

        Provide a Workato-specific response with:
        1. Recipe Design Assessment
           - Technical feasibility (feasible if score > 60)
           - Required connector authentication
           - Data mapping considerations

        2. Recipe Structure
           - Specific triggers and actions to use
           - Data transformation requirements
           - Error handling recommendations

        3. Implementation Notes
           - Connection setup requirements
           - Recipe testing guidelines
           - Performance considerations

        Format Guidelines:
        • Use **name** for connector names
        • Use bullet points (•)
        • Reference exact Workato trigger/action names
        • Focus on native Workato functionality
      PROMPT
    end

    def simple_capabilities_context(connector_names)
      "Available Workato Connectors: #{connector_names.join(", ")}"
    end


    def create_basic_context(capabilities_context)
      <<~PROMPT
        You are a Workato recipe design assistant. Focus on the following:
        
        #{capabilities_context}

        Provide a Workato-specific response with:
        1. Recipe Blueprint
           - Required trigger and action steps
           - Data mapping approach
           - Authentication requirements

        2. Implementation Steps
           - Connector setup process
           - Recipe configuration details
           - Testing recommendations

        Format Guidelines:
        • Use **name** for connector names
        • Use bullet points (•)
        • Reference specific Workato features
        • Focus on native Workato functionality
        • Avoid mentioning third-party platforms

        Remember:
        - All integrations should use native Workato recipes
        - Authentication uses Workato's connection manager
        - Data mapping occurs within the recipe builder
        - Testing uses Workato's recipe debugger
      PROMPT
    end

    def parse_requirements_response(response)
      return {
        source: { triggers: [], actions: [] },
        target: { triggers: [], actions: [] }
      } unless response

      begin
        parsed = JSON.parse(response)
        # Ensure the response has the expected structure
        {
          source: {
            triggers: parsed.dig('source', 'triggers') || [],
            actions: parsed.dig('source', 'actions') || []
          },
          target: {
            triggers: parsed.dig('target', 'triggers') || [],
            actions: parsed.dig('target', 'actions') || []
          }
        }
      rescue JSON::ParserError
        begin
          json_match = response.match(/\{.*\}/m)
          if json_match
            parsed = JSON.parse(json_match[0])
            # Apply same structure validation
            {
              source: {
                triggers: parsed.dig('source', 'triggers') || [],
                actions: parsed.dig('source', 'actions') || []
              },
              target: {
                triggers: parsed.dig('target', 'triggers') || [],
                actions: parsed.dig('target', 'actions') || []
              }
            }
          else
            {
              source: { triggers: [], actions: [] },
              target: { triggers: [], actions: [] }
            }
          end
        rescue
          {
            source: { triggers: [], actions: [] },
            target: { triggers: [], actions: [] }
          }
        end
      end
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
      return "" unless response

      # Clean up the raw text
      formatted = response.gsub(/\n{2,}/, '\n')
                          .gsub(/\s{2,}/, ' ')
                          .gsub(/\*\s+\*/, '**')

      # Format sections and points
      formatted = formatted.gsub(
        /(\d+\.\s*)(Technical Feasibility Assessment:|Required Connectors:|Integration Blueprint:|Enhancement Recommendations:|Integration Design:|Recommendations:)/,
        '\n\1\2'
      )
      formatted = formatted.gsub(/([.!?])\s+(\d+\.\s)/, '\1\n\2')
      formatted = formatted.gsub(/([.!?])\s+(\•\s)/, '\1\n\2')

      formatted.strip
    end

    def call_llm(system_context, prompt, short_response: false, timeout: 90, llm_options: nil)
      options = if llm_options
                  llm_options
                elsif short_response
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
      Rails.logger.info("Full prompt: #{full_prompt}")

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

    def handle_timeout_error(error, prompt, detected_mentions, retries)
      if retries > 0
        Rails.logger.warn("Timeout occurred. Retrying... (#{retries} attempts left)")
        sleep(RETRY_DELAY)
        generate_response(prompt, detected_mentions, retries: retries - 1)
      else
        Rails.logger.error("Final timeout error: #{error.message}")
        raise "Request timed out after multiple attempts. Please try again."
      end
    end

    def handle_general_error(error, prompt, detected_mentions, retries)
      if retries > 0
        Rails.logger.warn("Error occurred. Retrying... (#{retries} attempts left)")
        sleep(RETRY_DELAY)
        generate_response(prompt, detected_mentions, retries: retries - 1)
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