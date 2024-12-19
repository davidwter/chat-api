# app/services/connector_detection_service.rb
class ConnectorDetectionService
  def self.detect_and_save_mentions(message_id, content)
    Rails.logger.debug "Detecting connectors in: #{content}"

    # Get all connector names for detection
    connectors = Connector.includes(:categories).all
    detected = []

    # Clean up content for detection
    clean_content = content.gsub('**', '').downcase

    Rails.logger.debug "Cleaned content: #{clean_content}"
    Rails.logger.debug "Available connectors: #{connectors.map(&:name).join(', ')}"

    connectors.each do |connector|
      connector_name = connector.name.downcase
      Rails.logger.debug "Checking for connector: #{connector_name}"

      if clean_content.include?(connector_name)
        Rails.logger.debug "Found connector: #{connector.name}"
        detected << {
          connector: connector,
          confidence_score: 100.0
        }
      end
    end

    Rails.logger.debug "Detected connectors: #{detected.map { |d| d[:connector].name }.join(', ')}"

    # Save mentions
    detected.each do |detection|
      begin
        ConnectorMention.create!(
          message_id: message_id,
          connector_id: detection[:connector].id,
          confidence_score: detection[:confidence_score]
        )
        Rails.logger.debug "Created mention for: #{detection[:connector].name}"
      rescue => e
        Rails.logger.error "Failed to create connector mention: #{e.message}"
      end
    end

    detected
  end
end