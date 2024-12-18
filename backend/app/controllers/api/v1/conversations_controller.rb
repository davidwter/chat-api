module Api
  module V1
    class ConversationsController < ApplicationController
      def index
        conversations = Conversation.order(created_at: :desc)
        render json: {
          conversations: conversations.map { |c| conversation_json(c) }
        }
      end

      def create
        conversation = Conversation.create!(title: "New Conversation")
        render json: { conversation: conversation_json(conversation) }, status: :created
      end

      def show
        conversation = Conversation.find(params[:id])
        render json: { conversation: conversation_json(conversation) }
      end

      private

      def conversation_json(conversation)
        {
          id: conversation.id,
          title: conversation.title,
          status: conversation.status,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          last_message: conversation.messages.order(created_at: :desc).first&.content
        }
      end
    end
  end
end