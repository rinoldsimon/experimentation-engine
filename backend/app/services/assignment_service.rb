require "digest"

# Deterministically buckets a visitor into one of an experiment's variants,
# weighted by each variant's `weight`. The same experiment/visitor pair
# always hashes to the same bucket, so assignment is sticky across requests
# and server restarts without needing to persist anything up front.
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

    # Weights don't add up to BUCKET_COUNT (misconfigured experiment); fail
    # open with the last variant rather than returning no assignment.
    variants.last
  end

  private

  attr_reader :experiment, :visitor_id

  def variants
    @variants ||= experiment.variants.order(:created_at, :id).to_a
  end

  # Stable per experiment/visitor: same inputs always produce the same
  # bucket, which is what makes assignment deterministic and sticky.
  def bucket
    Digest::MD5.hexdigest("#{experiment.id}-#{visitor_id}").to_i(16) % BUCKET_COUNT
  end
end
