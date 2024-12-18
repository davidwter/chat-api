Rails.application.config.after_initialize do
  Rails.logger.info "Initializing LLM Service..."

  # Wait for Ollama service to be ready
  retries = 5
  begin
    LlmService.ensure_model_loaded
    Rails.logger.info "LLM Service initialized successfully"
  rescue => e
    if retries > 0
      retries -= 1
      Rails.logger.warn "Failed to initialize LLM Service, retrying in 5 seconds... (#{retries} retries left)"
      sleep 5
      retry
    else
      Rails.logger.error "Failed to initialize LLM Service after multiple retries: #{e.message}"
    end
  end
end