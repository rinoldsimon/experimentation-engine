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
end
