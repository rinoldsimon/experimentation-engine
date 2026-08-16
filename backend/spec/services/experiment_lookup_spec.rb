require "rails_helper"

RSpec.describe ExperimentLookup do
  # The app's test environment cache_store is :null_store (see
  # config/environments/test.rb), which never actually caches anything --
  # exactly right for most tests, but useless for exercising caching/fail-open
  # behavior here. Inject a real in-memory store instead.
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

  describe ".find_by_name!" do
    it "returns the experiment (with variants preloaded) for a known name" do
      experiment = create(:experiment, name: "known")
      create(:variant, experiment:)

      result = described_class.find_by_name!("known", cache_store:)

      expect(result).to eq(experiment)
      expect(result.association(:variants)).to be_loaded
    end

    it "raises NotFound (never caching it) for an unknown name" do
      expect {
        described_class.find_by_name!("does-not-exist", cache_store:)
      }.to raise_error(described_class::NotFound)

      expect(cache_store.exist?("experiment_lookup/v1/does-not-exist")).to be(false)
    end

    it "does not hit the database again for a repeat lookup within the fresh window" do
      experiment = create(:experiment, name: "known")

      described_class.find_by_name!("known", cache_store:)

      expect(Experiment).not_to receive(:includes)
      expect(described_class.find_by_name!("known", cache_store:)).to eq(experiment)
    end

    it "fails open to the cached experiment when the database errors on a later lookup" do
      experiment = create(:experiment, name: "known")
      described_class.find_by_name!("known", cache_store:) # warm the cache

      # Force the cache entry to look stale so the next call actually
      # attempts (and this time fails) a fresh database read.
      cache_store.write("experiment_lookup/v1/known", { experiment:, cached_at: 1.hour.ago })
      allow(Experiment).to receive(:includes).and_raise(PG::ConnectionBad, "could not connect")

      result = described_class.find_by_name!("known", cache_store:)

      expect(result).to eq(experiment)
    end

    it "raises Unavailable when the database errors and nothing is cached at all" do
      allow(Experiment).to receive(:includes).and_raise(PG::ConnectionBad, "could not connect")

      expect {
        described_class.find_by_name!("known", cache_store:)
      }.to raise_error(described_class::Unavailable)
    end
  end
end
