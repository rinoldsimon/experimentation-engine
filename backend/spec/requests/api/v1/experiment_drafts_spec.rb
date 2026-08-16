require "rails_helper"

RSpec.describe "Api::V1::ExperimentDrafts", type: :request do
  describe "POST /api/v1/experiment_drafts" do
    it "returns a draft without persisting anything" do
      allow(ExperimentDraftGenerator).to receive(:call).and_return(
        name: "newsletter_signup_test",
        variants: [
          { name: "control", weight: 50, content: "Subscribe to our newsletter" },
          { name: "urgency_cta", weight: 50, content: "Join 10,000+ readers -- subscribe free" }
        ]
      )

      expect {
        post "/api/v1/experiment_drafts", params: { topic: "Increase newsletter signups", variant_count: 2 }
      }.not_to change(Experiment, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("newsletter_signup_test")
      expect(response.parsed_body["variants"].size).to eq(2)
    end

    it "returns 422 (not a 500) when the topic is missing" do
      post "/api/v1/experiment_drafts"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 when generation fails" do
      allow(ExperimentDraftGenerator).to receive(:call).and_raise(
        ExperimentDraftGenerator::GenerationFailed, "Could not draft an experiment right now -- please try again"
      )

      post "/api/v1/experiment_drafts", params: { topic: "Increase newsletter signups" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to match(/try again/)
    end
  end
end
