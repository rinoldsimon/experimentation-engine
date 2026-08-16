module Api
  module V1
    class VariantsController < Api::V1::ApplicationController
      # On-demand LLM content generation for an existing variant -- the same
      # config-time-only call as ExperimentCreationService, just triggered
      # manually from the Dashboard instead of at creation time. Still never
      # touches the assignment path.
      def generate_content
        variant = Variant.find(params[:id])
        prompt = params.require(:content_prompt)

        result = VariantContentGenerator.call(prompt: prompt, fallback: variant.content.presence || variant.name)
        variant.update!(content: result.content, content_source: result.source)

        render json: serialize_variant(variant)
      end

      private

      def serialize_variant(variant)
        {
          id: variant.id,
          name: variant.name,
          weight: variant.weight,
          content: variant.content,
          content_source: variant.content_source
        }
      end
    end
  end
end
