class LlmService
  include HTTParty
  base_uri ENV.fetch('OLLAMA_HOST', 'ollama') + ':' + ENV.fetch('OLLAMA_PORT', '11434')
  default_timeout 120  # Increase timeout to 120 seconds

  def self.generate_response(prompt, retries = 3)
    ensure_model_loaded

    # Get all connectors with their categories
    connectors_context = Connector.includes(:categories).map do |connector|
      categories = connector.categories.map(&:name).join(", ")
      "#{connector.name} (#{categories})"
    end.join("\n")

    system_context = <<~PROMPT
      You are an integration assistant. Here are the available connectors:
      #{connectors_context}

      Guidelines:
      1. When users describe integration needs, identify and mention relevant connectors
      2. DO NOT discuss specific connector capabilities
      3. Only mention connectors from the list provided
      4. If you mention a connector, always use its exact name as provided above
      5. Format connector names in bold using markdown: **ConnectorName**

      Example response: "This integration would involve **QuickBooks** and **Fieldwire**."
    PROMPT

    begin
      response = post("/api/generate",
                      body: {
                        model: "mistral",
                        prompt: "#{system_context}\n\nUser: #{prompt}",
                        stream: false,
                        options: {
                          num_ctx: 2048,           # Reduce context size for faster responses
                          num_thread: 6,           # Adjust based on available CPU
                          temperature: 0.7,        # Add some randomness to responses
                          top_k: 40,              # Limit vocabulary selections
                          top_p: 0.9,             # Nucleus sampling
                          repeat_penalty: 1.1      # Prevent repetitive responses
                        }
                      }.to_json,
                      headers: { 'Content-Type' => 'application/json' },
                      timeout: 120  # Explicit timeout for this request
      )

      if response.success?
        response.parsed_response["response"]
      else
        Rails.logger.error("LLM Error: #{response.code} - #{response.body}")
        if retries > 0 && response.code == 404
          Rails.logger.info("Retrying after model not found error...")
          sleep 2  # Add small delay between retries
          ensure_model_loaded
          generate_response(prompt, retries - 1)
        else
          raise "Failed to generate response"
        end
      end
    rescue Net::ReadTimeout => e
      Rails.logger.error("LLM Timeout Error: #{e.message}")
      if retries > 0
        Rails.logger.info("Retrying after timeout...")
        sleep 2
        generate_response(prompt, retries - 1)
      else
        raise "Model response timeout after several retries"
      end
    rescue => e
      Rails.logger.error("LLM Service Error: #{e.message}")
      raise e
    end
  end

  private

  def self.ensure_model_loaded
    begin
      Rails.logger.info("Checking if model is loaded...")
      response = get("/api/show",
                     query: { name: "mistral" },
                     timeout: 30
      )

      return true if response.success?

      Rails.logger.info("Model not found, pulling mistral...")
      pull_response = post("/api/pull",
                           body: {
                             name: "mistral",
                             insecure: true
                           }.to_json,
                           headers: { 'Content-Type' => 'application/json' },
                           timeout: 300  # 5 minutes timeout for model pulling
      )

      unless pull_response.success?
        Rails.logger.error("Failed to pull model: #{pull_response.code} - #{pull_response.body}")
      end
    rescue => e
      Rails.logger.error("Error ensuring model is loaded: #{e.message}")
      raise e
    end
  end
end