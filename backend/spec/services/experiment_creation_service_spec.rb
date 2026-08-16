require "rails_helper"

RSpec.describe ExperimentCreationService do
  describe ".call" do
    it "creates an experiment with all of its variants when weights sum to 100" do
      experiment = described_class.call(
        name: "new_experiment",
        variants: [
          { name: "A", weight: 60 },
          { name: "B", weight: 40 }
        ]
      )

      expect(experiment).to be_persisted
      expect(experiment.variants.pluck(:name, :weight)).to contain_exactly([ "A", 60 ], [ "B", 40 ])
    end

    it "defaults status to running when not given" do
      experiment = described_class.call(name: "new_experiment", variants: [ { name: "A", weight: 100 } ])

      expect(experiment).to be_running
    end

    it "honours an explicitly given status" do
      experiment = described_class.call(
        name: "new_experiment",
        status: "paused",
        variants: [ { name: "A", weight: 100 } ]
      )

      expect(experiment).to be_paused
    end

    it "defaults source to manual when not given" do
      experiment = described_class.call(name: "new_experiment", variants: [ { name: "A", weight: 100 } ])

      expect(experiment).to be_manual
    end

    it "honours an explicitly given source" do
      experiment = described_class.call(
        name: "new_experiment",
        source: "ai_draft",
        variants: [ { name: "A", weight: 100 } ]
      )

      expect(experiment).to be_ai_draft
    end

    it "raises WeightsInvalid (not a 500) when weights don't sum to 100" do
      expect {
        described_class.call(name: "new_experiment", variants: [ { name: "A", weight: 50 } ])
      }.to raise_error(described_class::WeightsInvalid, /must sum to 100/)

      expect(Experiment.exists?(name: "new_experiment")).to be(false)
    end

    it "raises WeightsInvalid when no variants are given" do
      expect {
        described_class.call(name: "new_experiment", variants: [])
      }.to raise_error(described_class::WeightsInvalid, /At least one variant/)
    end

    it "rolls back the whole experiment when one variant is invalid" do
      expect {
        described_class.call(
          name: "new_experiment",
          variants: [
            { name: "A", weight: 50 },
            { name: "A", weight: 50 } # duplicate name -- fails Variant's uniqueness validation
          ]
        )
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Experiment.exists?(name: "new_experiment")).to be(false)
    end

    it "generates LLM content for a variant that requests it, via VariantContentGenerator" do
      allow(VariantContentGenerator).to receive(:call)
        .with(prompt: "Write a headline", fallback: "Default")
        .and_return(VariantContentGenerator::Result.new(content: "Generated!", source: "llm"))

      experiment = described_class.call(
        name: "new_experiment",
        variants: [
          {
            name: "A",
            weight: 100,
            content_source: "llm",
            content_prompt: "Write a headline",
            fallback_content: "Default"
          }
        ]
      )

      variant = experiment.variants.first
      expect(variant.content).to eq("Generated!")
      expect(variant.content_source).to eq("llm")
    end

    it "does not call VariantContentGenerator for a manual (non-LLM) variant" do
      expect(VariantContentGenerator).not_to receive(:call)

      experiment = described_class.call(name: "new_experiment", variants: [ { name: "A", weight: 100 } ])

      expect(experiment.variants.first.content_source).to eq("manual")
    end
  end
end
