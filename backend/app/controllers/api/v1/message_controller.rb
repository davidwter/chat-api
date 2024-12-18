module Api
  module V1
    class MessageController < ::ActionController::API
      def chat
        message = params[:message]

        response = {
          message: "Received: #{message}",
          status: 200
        }

        render json: response
      end
    end
  end
end