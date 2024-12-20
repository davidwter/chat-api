# app/services/recipe_generation_service.rb
class RecipeGenerationService
  class << self
    def generate_recipe(message_content, detected_mentions)
      # Validate we have exactly two connectors
      return error_response("Recipe generation requires exactly two connectors") unless detected_mentions&.length == 2

      source_connector = detected_mentions[0][:connector]
      target_connector = detected_mentions[1][:connector]

      # Get connector capabilities
      source_caps = ConnectorCapabilityService.get_capabilities([source_connector.name]).first
      target_caps = ConnectorCapabilityService.get_capabilities([target_connector.name]).first

      # Extract integration requirements
      requirements = LlmService.extract_integration_requirements(
        message_content,
        [source_connector.name, target_connector.name]
      )

      # Analyze feasibility
      feasibility = ConnectorCapabilityService.verify_integration_feasibility(
        source_connector.name,
        target_connector.name,
        requirements
      )

      # Generate recipe through LLM
      response = LlmService.generate_recipe(
        message_content,
        source_caps,
        target_caps,
        requirements,
        feasibility
      )

      {
        recipe: response,
        feasibility: feasibility,
        source_connector: source_connector.name,
        target_connector: target_connector.name
      }
    end

    private

    def error_response(message)
      {
        error: message,
        recipe: nil,
        feasibility: nil,
        source_connector: nil,
        target_connector: nil
      }
    end
  end
end