# app/services/llm_service.rb
class LlmService
  include HTTParty
  base_uri ENV.fetch('OLLAMA_HOST', 'http://ollama:11434')

  def self.generate_response(prompt)
    # First pass: identify relevant connectors
    connector_names = identify_relevant_connectors(prompt)

    # Get and format capabilities for identified connectors
    capabilities = ConnectorCapabilityService.get_capabilities(connector_names)
    capabilities_context = ConnectorCapabilityService.format_capabilities(capabilities)

    # Final response with capabilities context
    generate_detailed_response(prompt, capabilities_context)
  end

  private

  def self.identify_relevant_connectors(prompt)
    available_connectors = Connector.pluck(:name).join(", ")

    system_context = <<~PROMPT
      You are an integration assistant. Given a user's request, identify which connectors 
      are relevant. Return ONLY a JSON array of connector names, no other text.
      
      Available connectors:
      #{available_connectors}
    PROMPT

    response = call_llm(system_context, prompt)

    # Extract connector names from response, handle potential JSON parsing errors
    begin
      JSON.parse(response)
    rescue JSON::ParserError
      # Fallback: extract names using basic pattern matching if JSON parsing fails
      response.scan(/\"(.*?)\"/).flatten.uniq
    end
  end

  def self.generate_detailed_response(prompt, capabilities_context)
    system_context = <<~PROMPT
      You are an integration assistant with knowledge of connector capabilities.
      
      #{capabilities_context}
      
      Guidelines:
      1. Use exact trigger and action names in your response
      2. Highlight real-time capabilities when present
      3. Format connector names in bold using markdown: **ConnectorName**
      4. Be specific about what each connector can and cannot do
      5. If you're not sure about a capability, say so
      
      Always structure your complete response to include:
      1. Which connectors would be involved
      2. What specific triggers and actions would be used (list all required ones)
      3. Step by step explanation of how the integration would work
      4. Any notable limitations or requirements
      
      Important: Always provide complete responses without truncation. Ensure you fully explain each component.
    PROMPT

    call_llm(system_context, prompt)
  end

  def self.call_llm(system_context, prompt)
    full_prompt = "#{system_context}\n\nUser: #{prompt}"

    response = post("/api/generate",
                    body: {
                      model: "mistral",
                      prompt: full_prompt,
                      stream: false,
                      options: {
                        temperature: 0.7,
                        top_k: 40,
                        top_p: 0.9,
                        num_predict: 1000,  # Increased to allow for longer responses
                        stop: ["User:", "\n\n\n"]  # Stop generation at next user input or multiple newlines
                      }
                    }.to_json,
                    headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      response.parsed_response["response"]
    else
      Rails.logger.error("LLM Error: #{response.code} - #{response.body}")
      raise "Failed to generate response: #{response.code}"
    end
  end
end

# app/services/connector_capability_service.rb
class ConnectorCapabilityService
  def self.get_capabilities(connector_names)
    return [] if connector_names.empty?

    Connector.includes(:connector_triggers, :connector_actions)
             .where(name: connector_names)
             .map do |connector|
      {
        name: connector.name,
        triggers: connector.connector_triggers.map { |t|
          {
            name: t.name,
            description: t.description,
            feature_attributes: t.feature_attributes
          }
        },
        actions: connector.connector_actions.map { |a|
          {
            name: a.name,
            description: a.description,
            feature_attributes: a.feature_attributes
          }
        }
      }
    end
  end

  def self.format_capabilities(capabilities)
    capabilities.map do |connector|
      triggers = connector[:triggers].map { |t|
        badge = t[:feature_attributes]["badge"] ? " (#{t[:feature_attributes]["badge"]})" : ""
        "  - #{t[:name]}#{badge}: #{t[:description]}"
      }.join("\n")

      actions = connector[:actions].map { |a|
        "  - #{a[:name]}: #{a[:description]}"
      }.join("\n")

      <<~CONN
        #{connector[:name]}:
        Triggers:
        #{triggers}
        
        Actions:
        #{actions}
      CONN
    end.join("\n\n")
  end
end