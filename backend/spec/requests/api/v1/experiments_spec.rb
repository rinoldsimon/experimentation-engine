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

  describe "POST /api/v1/experiments" do
    it "creates an experiment with its variants and traffic allocation" do
      expect {
        post "/api/v1/experiments", params: {
          experiment: {
            name: "new_experiment",
            variants: [
              { name: "A", weight: 60 },
              { name: "B", weight: 40 }
            ]
          }
        }
      }.to change(Experiment, :count).by(1).and change(Variant, :count).by(2)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["name"]).to eq("new_experiment")
      expect(body["status"]).to eq("running")
      expect(body["variants"].pluck("name", "weight")).to contain_exactly([ "A", 60 ], [ "B", 40 ])
      expect(body["source"]).to eq("manual")
    end

    it "records source: ai_draft when the experiment was created from an AI draft" do
      post "/api/v1/experiments", params: {
        experiment: { name: "new_experiment", source: "ai_draft", variants: [ { name: "A", weight: 100 } ] }
      }

      expect(response.parsed_body["source"]).to eq("ai_draft")
    end

    it "returns 422 (not a 500) when variant weights don't sum to 100" do
      expect {
        post "/api/v1/experiments", params: {
          experiment: { name: "new_experiment", variants: [ { name: "A", weight: 50 } ] }
        }
      }.not_to change(Experiment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to match(/must sum to 100/)
    end

    it "returns 422 when the experiment name is already taken" do
      create(:experiment, name: "existing_experiment")

      post "/api/v1/experiments", params: {
        experiment: { name: "existing_experiment", variants: [ { name: "A", weight: 100 } ] }
      }

      expect(response).to have_http_status(:unprocessable_content)
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

  describe "DELETE /api/v1/experiments/:id" do
    it "deletes an AI-drafted experiment along with its variants and events" do
      experiment = create(:experiment, status: :running, source: :ai_draft)
      variant = create(:variant, experiment:)
      create(:event, experiment:, variant:, event_type: "exposure")

      expect {
        delete "/api/v1/experiments/#{experiment.id}"
      }.to change(Experiment, :count).by(-1).and change(Variant, :count).by(-1).and change(Event, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 422 (not deleted) for a manually-created experiment" do
      experiment = create(:experiment, status: :running, source: :manual)

      expect {
        delete "/api/v1/experiments/#{experiment.id}"
      }.not_to change(Experiment, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for an unknown experiment id" do
      delete "/api/v1/experiments/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
