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

        message = conversation.messages.create!(
          content: message_params[:content],
          message_type: message_params[:message_type],
          is_user: true
        )

        # Generate AI response
        ai_response = LlmService.generate_response(message.content)
        response = conversation.messages.create!(
          content: ai_response,
          is_user: false
        )

        render json: {
          message: message_json(message),
          response: message_json(response)
        }, status: :created
      end

      private

      def message_params
        params.require(:message).permit(:content, :message_type)
      end

      def message_json(message)
        {
          id: message.id,
          content: message.content,
          isUser: message.is_user,
          timestamp: message.created_at.to_i * 1000,
          status: message.status,
          type: message.message_type,
          conversationId: message.conversation_id
        }
      end
    end
  end
end