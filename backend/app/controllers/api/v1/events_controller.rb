module Api
  module V1
    class EventsController < Api::V1::ApplicationController
      def create
        if paused_experiment?
          return render json: { id: nil, tracked: false }, status: :ok
        end

        event = Event.new(event_params)

        if event.save
          render json: { id: event.id, tracked: true }, status: :created
        else
          render_existing_or_raise(event)
        end
      rescue ActiveRecord::RecordNotUnique
        render_existing_or_raise(event)
      end

      private

      def event_params
        params.permit(:experiment_id, :variant_id, :visitor_id, :event_type)
      end

      # Kill switch parity: drop events for a paused experiment, same as
      # AssignmentsController skipping exposure logging -- otherwise an
      # exposure-less conversion would permanently skew stats on resume.
      def paused_experiment?
        Experiment.find_by(id: event_params[:experiment_id])&.paused? || false
      end

      # A duplicate event isn't an error -- return the existing row with 200
      # instead of failing. Handles both the validation-failure path and the
      # race where a concurrent insert hits the DB's unique index first.
      def render_existing_or_raise(event)
        existing = Event.find_by(
          experiment_id: event.experiment_id,
          visitor_id: event.visitor_id,
          event_type: event.event_type
        )
        raise ActiveRecord::RecordInvalid, event if existing.nil?

        render json: { id: existing.id, tracked: false }, status: :ok
      end
    end
  end
end
