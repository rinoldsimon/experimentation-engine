class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, ExperimentLookup::NotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_content
  rescue_from ActionController::ParameterMissing, with: :render_unprocessable_content

  private

  def render_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def render_unprocessable_content(exception)
    render json: { error: exception.message }, status: :unprocessable_content
  end
end
