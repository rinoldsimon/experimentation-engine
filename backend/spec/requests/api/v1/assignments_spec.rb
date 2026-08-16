require "rails_helper"

RSpec.describe "Api::V1::Assignments", type: :request do
  describe "GET /api/v1/assignments" do
    context "when the experiment is running" do
      it "returns a deterministically assigned variant and logs an exposure" do
        experiment = create(:experiment, status: :running)
        create(:variant, experiment:, name: "A", weight: 100)

        expect {
          get "/api/v1/assignments", params: { experiment_name: experiment.name, visitor_id: "visitor-1" }
        }.to change(Event, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["name"]).to eq("A")
        expect(Event.last.event_type).to eq("exposure")
      end

      it "does not log a second exposure for a repeat visit" do
        experiment = create(:experiment, status: :running)
        create(:variant, experiment:, name: "A", weight: 100)
        get "/api/v1/assignments", params: { experiment_name: experiment.name, visitor_id: "visitor-1" }

        expect {
          get "/api/v1/assignments", params: { experiment_name: experiment.name, visitor_id: "visitor-1" }
        }.not_to change(Event, :count)
      end
    end

    context "when the experiment is paused" do
      it "always returns the first (Control) variant, bypassing the hashing algorithm" do
        experiment = create(:experiment, status: :paused)
        control = create(:variant, experiment:, name: "Control", weight: 0)
        create(:variant, experiment:, name: "Treatment", weight: 100)

        get "/api/v1/assignments", params: { experiment_name: experiment.name, visitor_id: "any-visitor" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["id"]).to eq(control.id)
      end

      it "does not log an exposure event" do
        experiment = create(:experiment, status: :paused)
        create(:variant, experiment:, name: "Control", weight: 100)

        expect {
          get "/api/v1/assignments", params: { experiment_name: experiment.name, visitor_id: "visitor-1" }
        }.not_to change(Event, :count)
      end
    end

    it "returns 404 for an unknown experiment name" do
      get "/api/v1/assignments", params: { experiment_name: "does-not-exist", visitor_id: "visitor-1" }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when visitor_id is missing" do
      experiment = create(:experiment, status: :running)

      get "/api/v1/assignments", params: { experiment_name: experiment.name }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
