class LlmService
  include HTTParty
  base_uri ENV.fetch('OLLAMA_HOST', 'ollama') + ':' + ENV.fetch('OLLAMA_PORT', '11434')

  def self.generate_response(prompt, retries = 3)
    ensure_model_loaded

    begin
      response = post("/api/generate",
                      body: {
                        model: "mistral",
                        prompt: prompt,
                        stream: false
                      }.to_json,
                      headers: { 'Content-Type' => 'application/json' }
      )

      if response.success?
        response.parsed_response["response"]
      else
        Rails.logger.error("LLM Error: #{response.code} - #{response.body}")
        if retries > 0 && response.code == 404
          Rails.logger.info("Retrying after model not found error...")
          ensure_model_loaded
          generate_response(prompt, retries - 1)
        else
          raise "Failed to generate response"
        end
      end
    rescue => e
      Rails.logger.error("LLM Service Error: #{e.message}")
      raise e
    end
  end

  private

  def self.ensure_model_loaded
    begin
      response = post("/api/pull",
                      body: {
                        name: "mistral",
                        insecure: true
                      }.to_json,
                      headers: { 'Content-Type' => 'application/json' }
      )

      unless response.success?
        Rails.logger.error("Failed to pull model: #{response.code} - #{response.body}")
      end
    rescue => e
      Rails.logger.error("Error ensuring model is loaded: #{e.message}")
    end
  end
end