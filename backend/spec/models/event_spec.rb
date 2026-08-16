require "rails_helper"

RSpec.describe Event, type: :model do
  it "is valid with valid attributes" do
    event = build(:event)

    expect(event).to be_valid
  end

  it "is valid without a variant" do
    event = build(:event, variant: nil)

    expect(event).to be_valid
  end

  it "is invalid without an experiment" do
    event = build(:event, experiment: nil)

    expect(event).not_to be_valid
    expect(event.errors[:experiment]).to include("must exist")
  end

  it "is invalid without a visitor_id" do
    event = build(:event, visitor_id: nil)

    expect(event).not_to be_valid
    expect(event.errors[:visitor_id]).to include("can't be blank")
  end

  it "is invalid without an event_type" do
    event = build(:event, event_type: nil)

    expect(event).not_to be_valid
    expect(event.errors[:event_type]).to include("can't be blank")
  end

  it "is invalid when [experiment_id, visitor_id, event_type] duplicates an existing event" do
    existing = create(:event, event_type: "conversion")
    duplicate = build(:event, experiment: existing.experiment, visitor_id: existing.visitor_id, event_type: "conversion")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:visitor_id]).to include("has already been taken")
  end

  it "is valid for the same visitor/event_type pair under a different experiment" do
    existing = create(:event, event_type: "conversion")
    other_experiment_event = build(:event, visitor_id: existing.visitor_id, event_type: "conversion")

    expect(other_experiment_event).to be_valid
  end
end
