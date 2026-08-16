require "digest"

# Deterministically buckets a visitor into a weighted variant. Same inputs
# always hash to the same bucket -- sticky, with nothing to persist.
class AssignmentService
  BUCKET_COUNT = 100

  def self.call(experiment, visitor_id)
    new(experiment, visitor_id).call
  end

  def initialize(experiment, visitor_id)
    @experiment = experiment
    @visitor_id = visitor_id
  end

  def call
    return nil if variants.empty?

    cumulative_weight = 0
    variants.each do |variant|
      cumulative_weight += variant.weight
      return variant if bucket < cumulative_weight
    end

    # Weights don't sum to 100 -- fail open to the last variant.
    variants.last
  end

  private

  attr_reader :experiment, :visitor_id

  def variants
    @variants ||= experiment.variants.order(:created_at, :id).to_a
  end

  def bucket
    Digest::MD5.hexdigest("#{experiment.id}-#{visitor_id}").to_i(16) % BUCKET_COUNT
  end
end
