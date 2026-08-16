require "rails_helper"

RSpec.describe "Api::V1::Events", type: :request do
  describe "POST /api/v1/events" do
    it "creates a new event and returns 201 Created" do
      experiment = create(:experiment)
      variant = create(:variant, experiment:)

      expect {
        post "/api/v1/events", params: {
          experiment_id: experiment.id,
          variant_id: variant.id,
          visitor_id: "visitor-1",
          event_type: "conversion"
        }
      }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["id"]).to eq(Event.last.id)
    end

    it "returns 200 OK (not an error) for a duplicate event instead of creating a second row" do
      experiment = create(:experiment)
      variant = create(:variant, experiment:)
      existing = create(:event, experiment:, variant:, visitor_id: "visitor-1", event_type: "conversion")

      expect {
        post "/api/v1/events", params: {
          experiment_id: experiment.id,
          variant_id: variant.id,
          visitor_id: "visitor-1",
          event_type: "conversion"
        }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(existing.id)
    end

    it "still returns 422 for a genuinely invalid event (no matching duplicate to fall back to)" do
      experiment = create(:experiment)

      post "/api/v1/events", params: { experiment_id: experiment.id, event_type: "conversion" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create an event for a paused experiment, matching AssignmentsController's kill switch" do
      experiment = create(:experiment, status: :paused)
      variant = create(:variant, experiment:)

      expect {
        post "/api/v1/events", params: {
          experiment_id: experiment.id,
          variant_id: variant.id,
          visitor_id: "visitor-1",
          event_type: "conversion"
        }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["tracked"]).to eq(false)
    end
  end
end
