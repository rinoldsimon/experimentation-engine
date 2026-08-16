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

      # Configuration API -- see ExperimentCreationService for weight
      # validation and optional LLM content generation.
      def create
        experiment = ExperimentCreationService.call(**experiment_params)

        render json: serialize_experiment(experiment, {}, {}), status: :created
      rescue ExperimentCreationService::WeightsInvalid => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      # Kill switch: flips between running and paused.
      def toggle_status
        experiment = Experiment.find(params[:id])
        experiment.update!(status: experiment.running? ? :paused : :running)

        variant_ids = experiment.variant_ids
        exposures_by_variant = event_counts_by_variant("exposure", variant_ids:)
        conversions_by_variant = event_counts_by_variant("conversion", variant_ids:)

        render json: serialize_experiment(experiment, exposures_by_variant, conversions_by_variant)
      end

      # Deletion is restricted to AI-drafted experiments -- the showcase/seeded
      # ones are meant to stay put, so this can't be used to wipe them out.
      def destroy
        experiment = Experiment.find(params[:id])
        return render_not_deletable unless experiment.ai_draft?

        experiment.destroy!
        head :no_content
      end

      private

      def render_not_deletable
        render json: { error: "Only AI-drafted experiments can be deleted" }, status: :unprocessable_content
      end

      def experiment_params
        permitted = params.require(:experiment).permit(
          :name, :status, :source,
          variants: [ :name, :weight, :content, :content_source, :content_prompt, :fallback_content ]
        )

        {
          name: permitted[:name],
          status: permitted[:status],
          source: permitted[:source],
          variants: (permitted[:variants] || []).map { |variant| variant.to_h.symbolize_keys }
        }
      end

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
          source: experiment.source,
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
          content: variant.content,
          content_source: variant.content_source,
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
