require "rails_helper"

RSpec.describe Variant, type: :model do
  it "is valid with valid attributes" do
    variant = build(:variant)

    expect(variant).to be_valid
  end

  it "is invalid without a name" do
    variant = build(:variant, name: nil)

    expect(variant).not_to be_valid
    expect(variant.errors[:name]).to include("can't be blank")
  end

  it "is invalid without an experiment" do
    variant = build(:variant, experiment: nil)

    expect(variant).not_to be_valid
    expect(variant.errors[:experiment]).to include("must exist")
  end

  it "is invalid with a negative weight" do
    variant = build(:variant, weight: -1)

    expect(variant).not_to be_valid
    expect(variant.errors[:weight]).to include("must be greater than or equal to 0")
  end

  it "is valid with a zero weight" do
    variant = build(:variant, weight: 0)

    expect(variant).to be_valid
  end

  it "is invalid with a duplicate name within the same experiment" do
    experiment = create(:experiment)
    create(:variant, experiment: experiment, name: "Control")
    duplicate = build(:variant, experiment: experiment, name: "Control")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "allows the same name across different experiments" do
    create(:variant, name: "Control")
    variant = build(:variant, name: "Control")

    expect(variant).to be_valid
  end

  it "nullifies its events' variant reference when destroyed" do
    variant = create(:variant)
    event = create(:event, experiment: variant.experiment, variant: variant)

    variant.destroy

    expect(event.reload.variant_id).to be_nil
  end
end
