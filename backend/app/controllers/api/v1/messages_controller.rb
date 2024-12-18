module Api
  module V1
    class MessagesController < ApplicationController
      def index
        messages = Message.order(created_at: :desc).limit(50)

        render json: {
          messages: messages,
          meta: {
            total_count: Message.count,
            returned_count: messages.size
          }
        }
      end

      def create
        message = Message.new(message_params.merge(
          is_user: true,
          status: 'sent'
        ))

        if message.save
          # Create bot response
          bot_message = Message.create!(
            content: generate_response(message.content),
            is_user: false,
            message_type: 'text',
            status: 'sent'
          )

          render json: {
            message: message,
            response: bot_message
          }, status: :created
        else
          render json: {
            errors: message.errors.full_messages,
            status: 'error'
          }, status: :unprocessable_entity
        end
      end

      private

      def message_params
        params.require(:message).permit(:content, :message_type)
      end

      def generate_response(content)
        # Placeholder for actual AI/LLM integration
        "Received your message: #{content}"
      end
    end
  end
end

