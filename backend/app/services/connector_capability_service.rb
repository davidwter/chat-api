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
            attributes: t.feature_attributes
          }
        },
        actions: connector.connector_actions.map { |a|
          {
            name: a.name,
            description: a.description,
            attributes: a.feature_attributes
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