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

      # Kill switch parity: AssignmentsController already skips exposure
      # logging and always serves the Control variant while an experiment is
      # paused. Any event submitted during that window (e.g. a conversion
      # from a demo page that has no idea -- and shouldn't need to know --
      # about pause state) is tracking noise, not real experiment data: an
      # exposure-less conversion would permanently pollute that variant's
      # stats even after the experiment is resumed. Silently drop it instead.
      def paused_experiment?
        Experiment.find_by(id: event_params[:experiment_id])&.paused? || false
      end

      # Idempotency: a duplicate event (same experiment/visitor/event_type) is
      # not an error from the client's point of view -- it just means this
      # exposure/conversion was already recorded, so hand back the existing
      # row with 200 OK instead of failing the request. This covers both the
      # common path (the model's uniqueness validation fails `event.save`)
      # and the race-condition path (two concurrent requests both pass
      # validation and only the DB's unique index catches the second insert).
      # Any other validation failure (e.g. a missing visitor_id) has no
      # existing row to fall back to, so it re-raises as a normal 422.
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
