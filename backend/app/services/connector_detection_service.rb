# app/services/connector_detection_service.rb
class ConnectorDetectionService
  def self.detect_and_save_mentions(message_id, content)
    # Get all connector names for detection
    connector_names = Connector.includes(:categories).all
    detected = []

    connector_names.each do |connector|
      # Simple name matching for hackathon - could be enhanced with NLP later
      if content.downcase.include?(connector.name.downcase)
        detected << {
          connector: connector,
          confidence_score: 100.0  # For hackathon, we'll use 100% if found
        }
      end
    end

    # Save mentions
    detected.each do |detection|
      ConnectorMention.create!(
        message_id: message_id,
        connector_id: detection[:connector].id,
        confidence_score: detection[:confidence_score]
      )
    end

    detected
  end
end