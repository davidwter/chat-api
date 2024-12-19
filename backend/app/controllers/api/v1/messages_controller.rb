module Api
  module V1
    class MessagesController < ApplicationController
      def index
        messages = if params[:conversation_id]
                     Conversation.find(params[:conversation_id]).messages
                   else
                     Message.all
                   end

        render json: {
          messages: messages.order(created_at: :asc).map { |m| message_json(m) }
        }
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

        # Generate AI response using LlmService with timeout handling
        begin
          Timeout.timeout(180) do  # 3 minutes total timeout
            ai_response = LlmService.generate_response(message.content)
            response = conversation.messages.create!(
              content: ai_response,
              is_user: false
            )

            # Detect and save connector mentions for both messages
            user_mentions = ConnectorDetectionService.detect_and_save_mentions(message.id, message.content)
            ai_mentions = ConnectorDetectionService.detect_and_save_mentions(response.id, response.content)

            render json: {
              message: message_json(message),
              response: message_json(response)
            }, status: :created
          end
        rescue Timeout::Error
          response = conversation.messages.create!(
            content: "I apologize, but I'm taking longer than expected to respond. Please try again.",
            is_user: false,
            message_type: 'error'
          )

          render json: {
            message: message_json(message),
            response: message_json(response)
          }, status: :created
        rescue StandardError => e
          Rails.logger.error("LLM Error: #{e.message}")
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