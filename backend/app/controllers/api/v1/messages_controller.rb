# app/controllers/api/v1/messages_controller.rb
module Api
  module V1
    class MessagesController < ApplicationController
      def index
        messages = if params[:conversation_id]
                     Conversation.find(params[:conversation_id]).messages
                   else
                     Message.all
                   end

        rendered_messages = messages.order(created_at: :asc).map do |message|
          # Get connector mentions with capability analysis
          mentions = analyze_connector_mentions(message)
          message_json(message, mentions)
        end

        render json: { messages: rendered_messages }
      end

      def create
        conversation = if params[:conversation_id]
                         Conversation.find(params[:conversation_id])
                       else
                         Conversation.create!(title: "New Conversation")
                       end

        # Create the initial user message
        message = create_user_message(conversation)

        # Detect connectors and analyze capabilities
        user_mentions = analyze_and_save_mentions(message)

        begin
          Timeout.timeout(180) do  # 3 minutes total timeout
            # Generate AI response with capability analysis
            ai_response = generate_ai_response(message.content, user_mentions)

            # Create response message with enhanced content
            response = create_ai_response(conversation, ai_response)

            # Analyze AI response for connector mentions
            ai_mentions = analyze_and_save_mentions(response)

            # Debug logging
            log_interaction(message, response, user_mentions, ai_mentions)

            render json: {
              message: message_json(message, user_mentions),
              response: message_json(response, ai_mentions)
            }, status: :created
          end
        rescue StandardError => e
          handle_error(e, conversation)
        end
      end

      private

      def create_user_message(conversation)
        conversation.messages.create!(
          content: message_params[:content],
          message_type: message_params[:message_type],
          is_user: true
        )
      end

      def create_ai_response(conversation, ai_response)
        conversation.messages.create!(
          content: ai_response,
          is_user: false
        )
      end

      def analyze_and_save_mentions(message)
        detected_mentions = ConnectorDetectionService.detect_and_save_mentions(
          message.id,
          message.content
        )

        # If we have exactly two connectors, analyze their compatibility
        if detected_mentions.length == 2
          source_connector = detected_mentions[0][:connector]
          target_connector = detected_mentions[1][:connector]

          # Extract requirements based on message content
          requirements = extract_requirements(message.content, source_connector, target_connector)

          # Analyze feasibility
          feasibility = ConnectorCapabilityService.verify_integration_feasibility(
            source_connector.name,
            target_connector.name,
            requirements
          )

          # Add feasibility info to mentions
          detected_mentions.each do |mention|
            mention[:capability_analysis] = {
              feasibility_score: feasibility[:feasibility][:score],
              missing_capabilities: feasibility[:missing_capabilities][mention[:connector].name == source_connector.name ? :source : :target],
              enhancement_suggestions: feasibility[:enhancement_suggestions].select { |s| s[:connector] == mention[:connector].name }
            }
          end
        end

        detected_mentions
      end

      def extract_requirements(content, source_connector, target_connector)
        # Use LLM to extract requirements
        requirements = LlmService.extract_integration_requirements(
          content,
          [source_connector.name, target_connector.name]
        )

        # Fallback to empty structure if extraction fails
        {
          source: {
            triggers: requirements.dig('source', 'triggers') || [],
            actions: requirements.dig('source', 'actions') || []
          },
          target: {
            triggers: requirements.dig('target', 'triggers') || [],
            actions: requirements.dig('target', 'actions') || []
          }
        }
      end

      def generate_ai_response(content, detected_mentions)
        if detected_mentions.length == 2
          # Use enhanced LLM response with capability analysis
          LlmService.generate_response(content)
        else
          # Use standard response for non-integration queries
          LlmService.generate_response(content)
        end
      end

      def analyze_connector_mentions(message)
        ConnectorMention.includes(:connector)
                        .where(message_id: message.id)
                        .map do |mention|
          {
            connector: mention.connector,
            confidence_score: mention.confidence_score,
            capability_analysis: get_cached_capability_analysis(mention)
          }
        end
      end

      def get_cached_capability_analysis(mention)
        # TODO: Implement caching for capability analysis
        # For now, return basic capability summary
        {
          total_triggers: mention.connector.connector_triggers.count,
          total_actions: mention.connector.connector_actions.count
        }
      end

      def message_json(message, detected_mentions = [])
        {
          id: message.id,
          content: message.content,
          isUser: message.is_user,
          timestamp: message.created_at.to_i * 1000,
          status: message.status,
          type: message.message_type,
          conversationId: message.conversation_id,
          connectors: format_connector_mentions(detected_mentions)
        }
      end

      def format_connector_mentions(mentions)
        mentions.map do |mention|
          {
            name: mention[:connector].name,
            categories: mention[:connector].categories.pluck(:name),
            confidenceScore: mention[:confidence_score],
            capabilities: {
              totalTriggers: mention.dig(:capability_analysis, :total_triggers),
              totalActions: mention.dig(:capability_analysis, :total_actions),
              feasibilityScore: mention.dig(:capability_analysis, :feasibility_score),
              missingCapabilities: mention.dig(:capability_analysis, :missing_capabilities),
              enhancementSuggestions: mention.dig(:capability_analysis, :enhancement_suggestions)
            }
          }
        end
      end

      def handle_error(error, conversation)
        Rails.logger.error("Error in message creation: #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))

        error_response = conversation.messages.create!(
          content: "I encountered an error while processing your message. Please try again.",
          is_user: false,
          message_type: 'error'
        )

        render json: {
          error: "Failed to process message: #{error.message}",
          response: message_json(error_response)
        }, status: :created
      end

      def log_interaction(message, response, user_mentions, ai_mentions)
        Rails.logger.debug "User message: #{message.content}"
        Rails.logger.debug "User mentions: #{user_mentions.inspect}"
        Rails.logger.debug "AI response: #{response.content}"
        Rails.logger.debug "AI mentions: #{ai_mentions.inspect}"
      end

      def message_params
        params.require(:message).permit(:content, :message_type)
      end
    end
  end
end