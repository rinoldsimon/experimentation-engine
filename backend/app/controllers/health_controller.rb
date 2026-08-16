class HealthController < ApplicationController
  def show
    render json: {
      status: "ok",
      service: "experimentation-engine",
      timestamp: Time.current
    }
  end
end
