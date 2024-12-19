# app/services/capability_gap_analyzer.rb
class CapabilityGapAnalyzer
  class << self
    def analyze(source_connector_name, target_connector_name, integration_requirements)
      source_connector = Connector.includes(:connector_triggers, :connector_actions)
                                  .find_by(name: source_connector_name)
      target_connector = Connector.includes(:connector_triggers, :connector_actions)
                                  .find_by(name: target_connector_name)

      return error_response("Source connector not found") unless source_connector
      return error_response("Target connector not found") unless target_connector

      {
        source_analysis: analyze_connector_capabilities(source_connector, integration_requirements[:source]),
        target_analysis: analyze_connector_capabilities(target_connector, integration_requirements[:target]),
        overall_feasibility: determine_overall_feasibility(source_connector, target_connector, integration_requirements),
        enhancement_suggestions: generate_enhancement_suggestions(source_connector, target_connector, integration_requirements)
      }
    end

    private

    def analyze_connector_capabilities(connector, requirements)
      return {} unless requirements

      required_triggers = requirements[:triggers] || []
      required_actions = requirements[:actions] || []

      available_triggers = connector.connector_triggers.map { |t| { name: t.name, description: t.description } }
      available_actions = connector.connector_actions.map { |a| { name: a.name, description: a.description } }

      missing_triggers = find_missing_capabilities(required_triggers, available_triggers)
      missing_actions = find_missing_capabilities(required_actions, available_actions)

      {
        connector_name: connector.name,
        available_capabilities: {
          triggers: available_triggers,
          actions: available_actions
        },
        missing_capabilities: {
          triggers: missing_triggers,
          actions: missing_actions
        },
        feasibility_score: calculate_feasibility_score(missing_triggers, missing_actions)
      }
    end

    def find_missing_capabilities(required, available)
      required.reject do |req_cap|
        available.any? { |avail_cap| capability_matches?(req_cap, avail_cap) }
      end
    end

    def capability_matches?(required, available)
      # First try exact name match
      return true if required.downcase == available[:name].downcase

      # Then check if the required capability appears in the description
      available[:description].present? &&
        available[:description].downcase.include?(required.downcase)
    end

    def calculate_feasibility_score(missing_triggers, missing_actions)
      # Returns a score from 0-100 based on missing capabilities
      return 100 if missing_triggers.empty? && missing_actions.empty?

      total_missing = missing_triggers.size + missing_actions.size
      base_score = 100 - (total_missing * 20) # Each missing capability reduces score by 20
      [base_score, 0].max # Ensure score doesn't go below 0
    end

    def determine_overall_feasibility(source_connector, target_connector, requirements)
      # Defensive checks
      return error_response("Requirements are nil") if requirements.nil?

      source_analysis = analyze_connector_capabilities(source_connector, requirements[:source] || {})
      target_analysis = analyze_connector_capabilities(target_connector, requirements[:target] || {})

      # Safely extract scores, defaulting to 0 if not found
      source_score = source_analysis[:feasibility_score] || 0
      target_score = target_analysis[:feasibility_score] || 0

      # Calculate average score safely
      average_score = (source_score + target_score) / 2.0

      {
        score: average_score,
        feasible: average_score > 60,
        constraints: identify_constraints(source_analysis, target_analysis)
      }
    rescue => e
      # Log the error for debugging
      Rails.logger.error("Error in determine_overall_feasibility:")
      Rails.logger.error("Source connector: #{source_connector&.name}")
      Rails.logger.error("Target connector: #{target_connector&.name}")
      Rails.logger.error("Requirements: #{requirements.inspect}")
      Rails.logger.error("Error: #{e.message}")

      error_response("Failed to determine overall feasibility: #{e.message}")
    end


    def identify_constraints(source_analysis, target_analysis)
      constraints = []

      # Add constraints based on missing capabilities
      source_missing = source_analysis.dig(:missing_capabilities, :triggers)
      if source_missing&.any?
        constraints << {
          type: :missing_triggers,
          connector: source_analysis[:connector_name],
          details: source_missing
        }
      end

      target_missing = target_analysis.dig(:missing_capabilities, :actions)
      if target_missing&.any?
        constraints << {
          type: :missing_actions,
          connector: target_analysis[:connector_name],
          details: target_missing
        }
      end

      constraints
    end

    def generate_enhancement_suggestions(source_connector, target_connector, requirements)
      constraints = determine_overall_feasibility(source_connector, target_connector, requirements)[:constraints]

      constraints.map do |constraint|
        {
          connector: constraint[:connector],
          type: constraint[:type],
          suggestions: format_suggestions(constraint),
          priority: calculate_priority(constraint)
        }
      end
    end

    def format_suggestions(constraint)
      case constraint[:type]
      when :missing_triggers
        constraint[:details].map do |trigger|
          {
            type: 'Add Trigger',
            name: trigger,
            description: "Add trigger capability for: #{trigger}"
          }
        end
      when :missing_actions
        constraint[:details].map do |action|
          {
            type: 'Add Action',
            name: action,
            description: "Add action capability for: #{action}"
          }
        end
      end
    end

    def calculate_priority(constraint)
      # Assign priority based on type and number of affected capabilities
      case constraint[:type]
      when :missing_triggers
        constraint[:details].size > 2 ? 'high' : 'medium'
      when :missing_actions
        constraint[:details].size > 2 ? 'high' : 'medium'
      else
        'low'
      end
    end

    def error_response(message)
      {
        error: message,
        overall_feasibility: {
          score: 0,
          feasible: false,
          constraints: [{
                          type: :error,
                          details: [message]
                        }]
        }
      }
    end
  end
end