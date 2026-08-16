require "rails_helper"

RSpec.describe "Api::V1::Variants", type: :request do
  describe "PATCH /api/v1/variants/:id/generate_content" do
    it "generates content via the LLM and persists it on the variant" do
      variant = create(:variant, content: nil, content_source: "manual")
      allow(VariantContentGenerator).to receive(:call).and_return(
        VariantContentGenerator::Result.new(content: "Free shipping, today only!", source: "llm")
      )

      patch "/api/v1/variants/#{variant.id}/generate_content", params: { content_prompt: "Write a headline" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("content" => "Free shipping, today only!", "content_source" => "llm")
      expect(variant.reload.content).to eq("Free shipping, today only!")
    end

    it "falls back gracefully (200, not 500) when generation fails" do
      variant = create(:variant, content: nil, content_source: "manual")
      allow(VariantContentGenerator).to receive(:call).and_return(
        VariantContentGenerator::Result.new(content: variant.name, source: "llm_fallback")
      )

      patch "/api/v1/variants/#{variant.id}/generate_content", params: { content_prompt: "Write a headline" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["content_source"]).to eq("llm_fallback")
    end

    it "returns 422 when content_prompt is missing" do
      variant = create(:variant)

      patch "/api/v1/variants/#{variant.id}/generate_content"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for an unknown variant id" do
      patch "/api/v1/variants/#{SecureRandom.uuid}/generate_content", params: { content_prompt: "x" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
