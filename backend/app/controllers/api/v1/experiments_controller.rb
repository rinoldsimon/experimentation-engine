module Api
  module V1
    class ExperimentsController < Api::V1::ApplicationController
      def index
        experiments = Experiment.includes(:variants).order(:created_at)
        exposures_by_variant = event_counts_by_variant("exposure")
        conversions_by_variant = event_counts_by_variant("conversion")

        render json: experiments.map { |experiment|
          serialize_experiment(experiment, exposures_by_variant, conversions_by_variant)
        }
      end

      # Kill switch: flips an experiment between running and paused. Paused
      # experiments are handled in AssignmentsController by always serving
      # the Control variant.
      def toggle_status
        experiment = Experiment.find(params[:id])
        experiment.update!(status: experiment.running? ? :paused : :running)

        variant_ids = experiment.variant_ids
        exposures_by_variant = event_counts_by_variant("exposure", variant_ids:)
        conversions_by_variant = event_counts_by_variant("conversion", variant_ids:)

        render json: serialize_experiment(experiment, exposures_by_variant, conversions_by_variant)
      end

      private

      # Grouping by variant_id (rather than experiment_id) lets the frontend
      # compare variants within an experiment to highlight a winner, and the
      # experiment-level totals below are simply the sum of its variants'.
      def event_counts_by_variant(event_type, variant_ids: nil)
        scope = Event.where(event_type:)
        scope = scope.where(variant_id: variant_ids) if variant_ids
        scope.group(:variant_id).count
      end

      def serialize_experiment(experiment, exposures_by_variant, conversions_by_variant)
        variants = experiment.variants.map { |variant| serialize_variant(variant, exposures_by_variant, conversions_by_variant) }
        exposures_count = variants.sum { |variant| variant[:exposures_count] }
        conversions_count = variants.sum { |variant| variant[:conversions_count] }

        {
          id: experiment.id,
          name: experiment.name,
          status: experiment.status,
          variants:,
          exposures_count:,
          conversions_count:,
          conversion_rate: conversion_rate(exposures_count, conversions_count)
        }
      end

      def serialize_variant(variant, exposures_by_variant, conversions_by_variant)
        exposures_count = exposures_by_variant[variant.id] || 0
        conversions_count = conversions_by_variant[variant.id] || 0

        {
          id: variant.id,
          name: variant.name,
          weight: variant.weight,
          exposures_count:,
          conversions_count:,
          conversion_rate: conversion_rate(exposures_count, conversions_count)
        }
      end

      def conversion_rate(exposures_count, conversions_count)
        return 0.0 if exposures_count.zero?

        (conversions_count.to_f / exposures_count).round(4)
      end
    end
  end
end
