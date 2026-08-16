module Api
  module V1
    class ExperimentDraftsController < Api::V1::ApplicationController
      rescue_from ExperimentDraftGenerator::GenerationFailed, with: :render_generation_failed

      # Never persists anything -- returns a suggested experiment/variants
      # shape for a human to review/edit before submitting it, unchanged,
      # to the real POST /api/v1/experiments.
      def create
        draft = ExperimentDraftGenerator.call(topic: params.require(:topic), variant_count: params[:variant_count])
        render json: draft
      end

      private

      def render_generation_failed(exception)
        render json: { error: exception.message }, status: :unprocessable_content
      end
    end
  end
end
