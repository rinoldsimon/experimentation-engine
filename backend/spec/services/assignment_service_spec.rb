require "rails_helper"

RSpec.describe AssignmentService do
  describe ".call" do
    it "returns the same variant for the same visitor_id every time" do
      experiment = create(:experiment)
      create(:variant, experiment:, name: "A", weight: 50)
      create(:variant, experiment:, name: "B", weight: 50)

      first_assignment = described_class.call(experiment, "visitor-123")
      second_assignment = described_class.call(experiment, "visitor-123")

      expect(first_assignment).to eq(second_assignment)
    end

    it "always assigns to the variant holding the full weight" do
      experiment = create(:experiment)
      full_variant = create(:variant, experiment:, name: "Full", weight: 100)
      create(:variant, experiment:, name: "Empty", weight: 0)

      5.times do |n|
        expect(described_class.call(experiment, "visitor-#{n}")).to eq(full_variant)
      end
    end

    it "distributes different visitors across variants according to weight" do
      experiment = create(:experiment)
      variant_a = create(:variant, experiment:, name: "A", weight: 50)
      variant_b = create(:variant, experiment:, name: "B", weight: 50)

      assignments = (1..200).map { |n| described_class.call(experiment, "visitor-#{n}") }.uniq

      expect(assignments).to contain_exactly(variant_a, variant_b)
    end

    it "returns nil when the experiment has no variants" do
      experiment = create(:experiment)

      expect(described_class.call(experiment, "visitor-123")).to be_nil
    end
  end
end
