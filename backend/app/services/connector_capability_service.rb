# app/services/connector_capability_service.rb
class ConnectorCapabilityService
  class << self
    def get_capabilities(connector_names)
      return [] if connector_names.empty?

      Connector.includes(:connector_triggers, :connector_actions, :categories)
               .where(name: connector_names)
               .map do |connector|
        {
          name: connector.name,
          description: connector.description,
          categories: connector.categories.map(&:name),
          triggers: format_triggers(connector.connector_triggers),
          actions: format_actions(connector.connector_actions),
          capability_summary: generate_capability_summary(connector)
        }
      end
    end

    def verify_integration_feasibility(source_name, target_name, requirements)
      source_capabilities = get_capabilities([source_name]).first
      target_capabilities = get_capabilities([target_name]).first

      return integration_error("Source connector not found") unless source_capabilities
      return integration_error("Target connector not found") unless target_capabilities

      # Get gap analysis
      gap_analysis = CapabilityGapAnalyzer.analyze(source_name, target_name, requirements)

      {
        feasibility: {
          is_feasible: gap_analysis[:overall_feasibility][:feasible],
          score: gap_analysis[:overall_feasibility][:score],
          constraints: gap_analysis[:overall_feasibility][:constraints]
        },
        capabilities: {
          source: source_capabilities,
          target: target_capabilities
        },
        missing_capabilities: {
          source: gap_analysis[:source_analysis][:missing_capabilities],
          target: gap_analysis[:target_analysis][:missing_capabilities]
        },
        enhancement_suggestions: gap_analysis[:enhancement_suggestions],
        category_compatibility: check_category_compatibility(
          source_capabilities[:categories],
          target_capabilities[:categories]
        )
      }
    end

    def format_capabilities_for_llm(capabilities)
      capabilities.map do |connector|
        triggers = format_triggers_for_llm(connector[:triggers])
        actions = format_actions_for_llm(connector[:actions])

        <<~CONN
          #{connector[:name]}:
          Categories: #{connector[:categories].join(', ')}
          
          Triggers:
          #{triggers}
          
          Actions:
          #{actions}
          
          Capability Summary:
          #{connector[:capability_summary]}
        CONN
      end.join("\n\n")
    end

    private

    def format_triggers(triggers)
      triggers.map do |trigger|
        {
          name: trigger.name,
          description: trigger.description,
          feature_attributes: trigger.feature_attributes || {},
          capability_type: categorize_capability(trigger)
        }
      end
    end

    def format_actions(actions)
      actions.map do |action|
        {
          name: action.name,
          description: action.description,
          feature_attributes: action.feature_attributes || {},
          capability_type: categorize_capability(action)
        }
      end
    end

    def categorize_capability(capability)
      return 'standard' unless capability.feature_attributes.present?

      if capability.feature_attributes['badge'] == 'Real-time'
        'real-time'
      elsif capability.feature_attributes['custom']
        'custom'
      else
        'standard'
      end
    end

    def generate_capability_summary(connector)
      {
        total_triggers: connector.connector_triggers.count,
        total_actions: connector.connector_actions.count,
        real_time_capabilities: count_real_time_capabilities(connector),
        supported_categories: connector.categories.pluck(:name)
      }
    end

    def count_real_time_capabilities(connector)
      triggers = connector.connector_triggers.count { |t| t.feature_attributes['badge'] == 'Real-time' }
      actions = connector.connector_actions.count { |a| a.feature_attributes['badge'] == 'Real-time' }
      triggers + actions
    end

    def check_category_compatibility(source_categories, target_categories)
      # Ensure we're working with arrays
      source_cats = Array(source_categories)
      target_cats = Array(target_categories)

      shared_categories = source_cats & target_cats

      {
        has_shared_categories: shared_categories.any?,
        shared_categories: shared_categories,
        compatibility_score: calculate_category_compatibility_score(shared_categories),
        recommendations: generate_category_recommendations(shared_categories)
      }
    end

    def calculate_category_compatibility_score(shared_categories)
      base_score = shared_categories.any? ? 70 : 30
      additional_score = [shared_categories.size * 10, 30].min
      base_score + additional_score
    end

    def generate_category_recommendations(shared_categories)
      if shared_categories.empty?
        [
          "Consider adding shared categories to improve compatibility",
          "Verify if the integration across different categories is intended",
          "Check if additional middleware connectors are needed"
        ]
      else
        [
          "Integration appears category-compatible",
          "Consider exploring additional shared categories for enhanced integration",
          "Review category-specific features and limitations"
        ]
      end
    end

    def format_triggers_for_llm(triggers)
      triggers.map do |trigger|
        badge = trigger[:feature_attributes]["badge"] ? " (#{trigger[:feature_attributes]["badge"]})" : ""
        "  - #{trigger[:name]}#{badge}: #{trigger[:description]}"
      end.join("\n")
    end

    def format_actions_for_llm(actions)
      actions.map do |action|
        badge = action[:feature_attributes]["badge"] ? " (#{action[:feature_attributes]["badge"]})" : ""
        "  - #{action[:name]}#{badge}: #{action[:description]}"
      end.join("\n")
    end

    def integration_error(message)
      {
        feasibility: {
          is_feasible: false,
          score: 0,
          constraints: [{
                          type: :error,
                          details: [message]
                        }]
        },
        capabilities: {
          source: nil,
          target: nil
        },
        missing_capabilities: {
          source: [],
          target: []
        },
        enhancement_suggestions: [],
        category_compatibility: {
          has_shared_categories: false,
          shared_categories: [],
          compatibility_score: 0,
          recommendations: ["Error: #{message}"]
        }
      }
    end
  end
end