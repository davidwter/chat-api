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
          # Get connector mentions for each message
          mentions = ConnectorMention.includes(:connector)
                                     .where(message_id: message.id)
                                     .map do |mention|
            {
              connector: mention.connector,
              confidence_score: mention.confidence_score
            }
          end
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
        message = conversation.messages.create!(
          content: message_params[:content],
          message_type: message_params[:message_type],
          is_user: true
        )

        # Detect connectors in user message
        user_mentions = ConnectorDetectionService.detect_and_save_mentions(message.id, message.content)

        begin
          Timeout.timeout(180) do  # 3 minutes total timeout
            ai_response = LlmService.generate_response(message.content)
            response = conversation.messages.create!(
              content: ai_response,
              is_user: false
            )

            # Detect connectors in AI response
            ai_mentions = ConnectorDetectionService.detect_and_save_mentions(response.id, response.content)

            # Debug logging
            Rails.logger.debug "User message: #{message.content}"
            Rails.logger.debug "User mentions: #{user_mentions.inspect}"
            Rails.logger.debug "AI response: #{response.content}"
            Rails.logger.debug "AI mentions: #{ai_mentions.inspect}"

            render json: {
              message: message_json(message, user_mentions),
              response: message_json(response, ai_mentions)
            }, status: :created
          end
        rescue => e
          Rails.logger.error("Error in message creation: #{e.message}")
          response = conversation.messages.create!(
            content: "I encountered an error while processing your message. Please try again.",
            is_user: false,
            message_type: 'error'
          )

          render json: {
            message: message_json(message),
            response: message_json(response)
          }, status: :created
        end
      end

      private

      def message_params
        params.require(:message).permit(:content, :message_type)
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
          connectors: detected_mentions.map { |m| {
            name: m[:connector].name,
            categories: m[:connector].categories.pluck(:name),
            confidenceScore: m[:confidence_score]
          }}
        }
      end
    end
  end
end