# Caches the experiment+variants lookup for the assignment path (see
# DESIGN.md "Scale"/"Reliability"). A DB error falls back to a stale cached
# snapshot if one exists (Unavailable is only raised when nothing is
# cached); a genuine "no such experiment" (NotFound) is never cached and
# never falls back -- it's a client error, not an outage.
class ExperimentLookup
  FRESH_TTL = 30.seconds

  class NotFound < StandardError; end
  class Unavailable < StandardError; end

  def self.find_by_name!(name, cache_store: Rails.cache)
    new(name, cache_store:).find!
  end

  def initialize(name, cache_store: Rails.cache)
    @name = name
    @cache_store = cache_store
  end

  def find!
    entry = cache_store.read(cache_key)
    return entry[:experiment] if entry && fresh?(entry)

    fetch_and_cache_fresh_experiment
  rescue ActiveRecord::ActiveRecordError, PG::Error => e
    Rails.logger.error("ExperimentLookup: DB unavailable while looking up '#{name}' (#{e.class}): #{e.message}")
    raise Unavailable, "Experiment configuration is temporarily unavailable" unless entry

    entry[:experiment]
  end

  private

  attr_reader :name, :cache_store

  def cache_key
    "experiment_lookup/v1/#{name}"
  end

  def fresh?(entry)
    entry[:cached_at] > FRESH_TTL.ago
  end

  def fetch_and_cache_fresh_experiment
    experiment = Experiment.includes(:variants).find_by(name: name)
    raise NotFound, "No experiment named '#{name}'" if experiment.nil?

    cache_store.write(cache_key, { experiment:, cached_at: Time.current })
    experiment
  end
end
