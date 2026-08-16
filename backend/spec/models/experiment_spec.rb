require "rails_helper"

RSpec.describe Experiment, type: :model do
  it "is valid with valid attributes" do
    experiment = build(:experiment)

    expect(experiment).to be_valid
  end

  it "is invalid without a name" do
    experiment = build(:experiment, name: nil)

    expect(experiment).not_to be_valid
    expect(experiment.errors[:name]).to include("can't be blank")
  end

  it "is invalid with a duplicate name" do
    create(:experiment, name: "Checkout Button Color")
    duplicate = build(:experiment, name: "Checkout Button Color")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "defaults to a running status" do
    expect(Experiment.new.status).to eq("running")
  end

  it "exposes the expected statuses" do
    expect(Experiment.statuses.keys).to contain_exactly("running", "paused")
  end

  it "destroys its variants when destroyed" do
    experiment = create(:experiment)
    create(:variant, experiment: experiment)

    expect { experiment.destroy }.to change(Variant, :count).by(-1)
  end

  it "destroys its events when destroyed" do
    experiment = create(:experiment)
    create(:event, experiment: experiment)

    expect { experiment.destroy }.to change(Event, :count).by(-1)
  end
end
