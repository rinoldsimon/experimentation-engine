module Api
  module V1
    class AssignmentsController < Api::V1::ApplicationController
      def show
        experiment = Experiment.find_by!(name: params.require(:experiment_name))
        visitor_id = params.require(:visitor_id)

        # Kill switch: a paused experiment bypasses the hashing algorithm
        # entirely and always serves the Control (first) variant, with no
        # exposure logged, so pausing instantly and uniformly stops the test
        # for every visitor without waiting on cache invalidation anywhere.
        variant = experiment.paused? ? control_variant(experiment) : AssignmentService.call(experiment, visitor_id)
        return render_no_variants if variant.nil?

        log_exposure(experiment:, variant:, visitor_id:) unless experiment.paused?

        render json: serialize_variant(variant)
      end

      private

      def control_variant(experiment)
        experiment.variants.order(:created_at, :id).first
      end

      # Exposure logging is best-effort analytics, not part of the assignment
      # contract: never let a write hiccup here stop a visitor from receiving
      # their (already-computed) variant.
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

      def serialize_variant(variant)
        {
          id: variant.id,
          name: variant.name,
          experiment_id: variant.experiment_id
        }
      end
    end
  end
end
