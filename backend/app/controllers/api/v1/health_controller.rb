class Api::V1::HealthController < ApplicationController
  def check
    render json: { status: 'ok', environment: Rails.env, time: Time.current }
  end
end