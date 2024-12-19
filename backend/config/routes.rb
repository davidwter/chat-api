# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'health/check', to: 'health#check'

      resources :messages, only: [:index, :create] do
        post :chat, on: :collection
      end

      resources :conversations do
        resources :messages, only: [:index, :create]
      end
    end
  end
end