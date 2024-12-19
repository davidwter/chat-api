# app/services/llm_service.rb
class LlmService
  include HTTParty
  base_uri ENV.fetch('OLLAMA_HOST', 'http://ollama:11434')
  default_timeout 120  # 2 minutes total timeout

  # Default retry settings
  RETRY_COUNT = 2
  RETRY_DELAY = 1  # seconds

  def self.generate_response(prompt, retries: RETRY_COUNT)
    with_timing do
      # First pass: identify relevant connectors with shorter timeout
      Rails.logger.info("Starting connector identification...")
      connector_names = identify_relevant_connectors(prompt)
      Rails.logger.info("Identified connectors: #{connector_names.join(', ')}")

      # Get capabilities context (from DB, should be fast)
      Rails.logger.info("Fetching capabilities...")
      capabilities = ConnectorCapabilityService.get_capabilities(connector_names)
      capabilities_context = ConnectorCapabilityService.format_capabilities(capabilities)

      # Final response with capabilities context
      Rails.logger.info("Generating detailed response...")
      generate_detailed_response(prompt, capabilities_context)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
    handle_timeout_error(e, prompt, retries)
  rescue => e
    handle_general_error(e, retries)
  end

  private

  def self.with_timing
    start_time = Time.now
    result = yield
    duration = Time.now - start_time
    Rails.logger.info("LLM request completed in #{duration.round(2)} seconds")
    result
  end

  def self.handle_timeout_error(error, prompt, retries)
    if retries > 0
      Rails.logger.warn("Timeout occurred. Retrying... (#{retries} attempts left)")
      sleep(RETRY_DELAY)
      generate_response(prompt, retries: retries - 1)
    else
      Rails.logger.error("Final timeout error: #{error.message}")
      raise "Request timed out after multiple attempts. Please try again."
    end
  end

  def self.handle_general_error(error, retries)
    if retries > 0
      Rails.logger.warn("Error occurred. Retrying... (#{retries} attempts left)")
      sleep(RETRY_DELAY)
      generate_response(prompt, retries: retries - 1)
    else
      Rails.logger.error("Final error: #{error.message}")
      raise "Failed to generate response after multiple attempts: #{error.message}"
    end
  end

  def self.identify_relevant_connectors(prompt)
    available_connectors = Connector.pluck(:name).join(", ")

    system_context = <<~PROMPT
      You are an integration assistant. Given a user's request, identify which connectors 
      are relevant. Return ONLY a JSON array of connector names, no other text.
      
      Available connectors:
      #{available_connectors}
    PROMPT

    # Use shorter timeout for initial connector identification
    response = call_llm(system_context, prompt,
                        short_response: true,
                        timeout: 30)  # 30 second timeout for this simpler task

    begin
      JSON.parse(response)
    rescue JSON::ParserError
      response.scan(/\"(.*?)\"/).flatten.uniq
    end
  end

  def self.generate_detailed_response(prompt, capabilities_context)
    system_context = <<~PROMPT
    You are an integration assistant specifically for the Workato iPaaS platform.
    
    #{capabilities_context}
    
    Format your response with these exact sections:
    1. Required Connectors: List connectors (one line)
    2. Triggers and Actions: List all specific triggers and actions needed (detailed list)
    3. Integration Steps: Clear steps for Workato recipe creation (numbered)
    4. Limitations: Key implementation considerations (bullet points)
    
    Use these formatting rules:
    - Use double asterisks together for bold (e.g., **Slack**, not * * Slack)
    - Use bullet points (•) for lists
    - Use exact trigger and action names
    - Mention only Workato-specific features
    - Use "recipe" instead of "workflow"
    
    Example formatting:
    1. Required Connectors: **Slack** and **Gmail**
    2. Triggers and Actions: • **Slack** trigger: 'New message' • **Gmail** action: 'Send email'
  PROMPT

    call_llm(system_context, prompt, timeout: 90)
  end

  def self.format_response(response)
    # Clean up the raw text
    formatted = response.gsub(/\n{2,}/, '\n') # Reduce multiple newlines to single
    formatted = formatted.gsub(/\s{2,}/, ' ')  # Clean up excessive spaces

    # Fix cases where stars are separated by spaces (e.g., * * text -> **text)
    formatted = formatted.gsub(/\*\s+\*/, '**')

    # Add newlines for sections
    formatted = formatted.gsub(/(\d+\.\s*)(Required Connectors:|Triggers and Actions:|Integration Steps:|Limitations:)/,
                               '\n\1\2')

    # Format sub-points
    formatted = formatted.gsub(/([.!?])\s+(\d+\.\s)/, '\1\n\2')
    formatted = formatted.gsub(/([.!?])\s+(\•\s)/, '\1\n\2')

    formatted.strip
  end



  def self.call_llm(system_context, prompt, short_response: false, timeout: 90)
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
      response_text = response.parsed_response["response"]
      short_response ? response_text : format_response(response_text)
    else
      Rails.logger.error("LLM Error: #{response.code} - #{response.body}")
      raise "Failed to generate response: #{response.code}"
    end
  end
end