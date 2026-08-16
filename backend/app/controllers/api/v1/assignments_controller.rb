module Api
  module V1
    class AssignmentsController < Api::V1::ApplicationController
      # DB outage + nothing cached: fail open instead of a 5xx (see DESIGN.md).
      rescue_from ExperimentLookup::Unavailable, with: :render_degraded_assignment

      def show
        experiment = ExperimentLookup.find_by_name!(params.require(:experiment_name))
        visitor_id = params.require(:visitor_id)

        # Kill switch: paused experiments always get Control, no hashing.
        variant = experiment.paused? ? control_variant(experiment) : AssignmentService.call(experiment, visitor_id)
        return render_no_variants if variant.nil?

        log_exposure(experiment:, variant:, visitor_id:) unless experiment.paused?

        render json: serialize_variant(variant)
      end

      private

      def control_variant(experiment)
        experiment.variants.order(:created_at, :id).first
      end

      # Best-effort: a logging failure must never fail the assignment itself.
      def log_exposure(experiment:, variant:, visitor_id:)
        Event.find_or_create_by!(experiment:, visitor_id:, event_type: "exposure") do |event|
          event.variant = variant
        end
      rescue ActiveRecord::ActiveRecordError => e
        Rails.logger.error(
          "Failed to log exposure for experiment=#{experiment.id} visitor_id=#{visitor_id}: #{e.message}"
        )
      end

      def render_no_variants
        render json: { error: "Experiment has no variants configured" }, status: :unprocessable_content
      end

      # Last resort: same 200 shape as a normal assignment, flagged degraded.
      def render_degraded_assignment(_exception)
        render json: { id: nil, name: "control", experiment_id: nil, content: nil, degraded: true }, status: :ok
      end

      def serialize_variant(variant)
        {
          id: variant.id,
          name: variant.name,
          experiment_id: variant.experiment_id,
          content: variant.content
        }
      end
    end
  end
end
