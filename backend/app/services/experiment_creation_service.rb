# Configuration API: creates an Experiment and all its Variants atomically.
# LLM content (if requested) is generated before the transaction opens --
# an external call shouldn't hold DB locks. See DESIGN.md "The LLM decision".
class ExperimentCreationService
  class WeightsInvalid < StandardError; end

  def self.call(name:, variants:, status: nil, source: nil)
    new(name:, variants:, status:, source:).call
  end

  def initialize(name:, variants:, status: nil, source: nil)
    @name = name
    @status = status.presence || "running"
    @source = source.presence || "manual"
    @variant_attrs = variants || []
  end

  def call
    validate_variants_present!
    validate_weights_sum_to_100!

    resolved_variants = variant_attrs.map { |attrs| resolve_content(attrs) }

    ActiveRecord::Base.transaction do
      experiment = Experiment.create!(name: name, status: status, source: source)
      resolved_variants.each { |attrs| experiment.variants.create!(attrs) }
      experiment
    end
  end

  private

  attr_reader :name, :status, :source, :variant_attrs

  def validate_variants_present!
    raise WeightsInvalid, "At least one variant is required" if variant_attrs.empty?
  end

  def validate_weights_sum_to_100!
    total = variant_attrs.sum { |attrs| attrs[:weight].to_i }
    return if total == 100

    raise WeightsInvalid, "Variant weights must sum to 100 (got #{total})"
  end

  def resolve_content(attrs)
    attrs = attrs.dup
    prompt = attrs.delete(:content_prompt)
    fallback = attrs.delete(:fallback_content)

    return attrs unless attrs[:content_source] == "llm"

    result = VariantContentGenerator.call(prompt:, fallback: fallback.presence || attrs[:name])
    attrs.merge(content: result.content, content_source: result.source)
  end
end
