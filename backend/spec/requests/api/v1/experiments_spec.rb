require "rails_helper"

RSpec.describe "Api::V1::Experiments", type: :request do
  describe "GET /api/v1/experiments" do
    it "returns experiments with per-variant and experiment-level exposure/conversion counts" do
      experiment = create(:experiment, status: :running)
      variant_a = create(:variant, experiment:, name: "A", weight: 50)
      variant_b = create(:variant, experiment:, name: "B", weight: 50)
      create(:event, experiment:, variant: variant_a, event_type: "exposure")
      create(:event, experiment:, variant: variant_a, event_type: "exposure", visitor_id: "visitor-2")
      create(:event, experiment:, variant: variant_a, event_type: "conversion")
      create(:event, experiment:, variant: variant_b, event_type: "exposure", visitor_id: "visitor-3")

      get "/api/v1/experiments"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body.first
      expect(body["id"]).to eq(experiment.id)

      variants = body["variants"].index_by { |variant| variant["name"] }
      expect(variants["A"]).to include("exposures_count" => 2, "conversions_count" => 1, "conversion_rate" => 0.5)
      expect(variants["B"]).to include("exposures_count" => 1, "conversions_count" => 0, "conversion_rate" => 0.0)

      expect(body["exposures_count"]).to eq(3)
      expect(body["conversions_count"]).to eq(1)
      expect(body["conversion_rate"]).to eq(0.3333)
    end

    it "returns zero counts and a zero conversion rate for an experiment with no events" do
      create(:experiment, status: :running)

      get "/api/v1/experiments"

      body = response.parsed_body.first
      expect(body["exposures_count"]).to eq(0)
      expect(body["conversions_count"]).to eq(0)
      expect(body["conversion_rate"]).to eq(0.0)
    end
  end

  describe "PATCH /api/v1/experiments/:id/toggle_status" do
    it "pauses a running experiment" do
      experiment = create(:experiment, status: :running)

      patch "/api/v1/experiments/#{experiment.id}/toggle_status"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("paused")
      expect(experiment.reload).to be_paused
    end

    it "resumes a paused experiment" do
      experiment = create(:experiment, status: :paused)

      patch "/api/v1/experiments/#{experiment.id}/toggle_status"

      expect(response.parsed_body["status"]).to eq("running")
      expect(experiment.reload).to be_running
    end

    it "returns 404 for an unknown experiment id" do
      patch "/api/v1/experiments/#{SecureRandom.uuid}/toggle_status"

      expect(response).to have_http_status(:not_found)
    end
  end
end
