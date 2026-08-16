require "net/http"
require "json"

# Drafts a full experiment (name, variants, weights, copy) from a plain-
# English topic via Gemini's structured JSON output. Config-time only, same
# as VariantContentGenerator -- and unlike it, this never persists anything
# or silently falls back: a human reviews/edits the draft on the Dashboard
# before it's submitted, unchanged in shape, to the real, already-validated
# ExperimentCreationService. See DESIGN.md "The LLM decision".
class ExperimentDraftGenerator
  class GenerationFailed < StandardError; end

  ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent".freeze
  REQUEST_TIMEOUT_SECONDS = 10
  VARIANT_COUNT_RANGE = 2..5

  RESPONSE_SCHEMA = {
    type: "OBJECT",
    properties: {
      name: { type: "STRING" },
      variants: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            name: { type: "STRING" },
            weight: { type: "NUMBER" },
            content: { type: "STRING" }
          },
          required: %w[name weight content]
        }
      }
    },
    required: %w[name variants]
  }.freeze

  def self.call(topic:, variant_count: 2)
    new(topic:, variant_count:).call
  end

  def initialize(topic:, variant_count: 2)
    @topic = topic.to_s.strip
    @variant_count = variant_count.to_i.clamp(VARIANT_COUNT_RANGE)
  end

  def call
    raise GenerationFailed, "Please describe what you want to test" if topic.blank?
    raise GenerationFailed, "AI drafting isn't configured (no GEMINI_API_KEY)" if api_key.blank?

    response = post_to_gemini
    raise GenerationFailed, "Gemini request failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    normalize(parse_draft(response.body))
  rescue GenerationFailed
    raise
  rescue StandardError => e
    Rails.logger.error("ExperimentDraftGenerator failed (#{e.class}): #{e.message}")
    raise GenerationFailed, "Could not draft an experiment right now -- please try again"
  end

  private

  attr_reader :topic, :variant_count

  def api_key
    ENV["GEMINI_API_KEY"]
  end

  def post_to_gemini
    uri = URI("#{ENDPOINT}?key=#{api_key}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = REQUEST_TIMEOUT_SECONDS
    http.read_timeout = REQUEST_TIMEOUT_SECONDS

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = {
      contents: [ { parts: [ { text: prompt } ] } ],
      generationConfig: { responseMimeType: "application/json", responseSchema: RESPONSE_SCHEMA }
    }.to_json

    http.request(request)
  end

  def prompt
    "You are designing an A/B test for a product team. Topic: \"#{topic}\". " \
      "Propose exactly #{variant_count} variants, including a \"control\" baseline. " \
      "Each variant needs a short snake_case name, an integer traffic weight (all " \
      "weights across variants must sum to 100), and one short sentence of " \
      "user-facing copy embodying that variant's approach. Also propose a short " \
      "snake_case name for the experiment itself."
  end

  def parse_draft(body)
    text = JSON.parse(body).dig("candidates", 0, "content", "parts", 0, "text")
    raise GenerationFailed, "Gemini returned an empty response" if text.blank?

    JSON.parse(text)
  end

  def normalize(draft)
    variants = normalize_variants(Array(draft["variants"]))
    raise GenerationFailed, "Gemini didn't return any usable variants" if variants.empty?

    { name: unique_experiment_name(slugify(draft["name"], fallback: topic)), variants: }
  end

  def normalize_variants(raw_variants)
    used_names = []
    sanitized = raw_variants.first(variant_count).map.with_index do |variant, index|
      name = unique_within(slugify(variant["name"], fallback: "variant_#{index + 1}"), used_names)
      used_names << name
      { name:, weight: variant["weight"].to_f, content: variant["content"].to_s.strip.presence || name }
    end

    rebalance_weights(sanitized)
  end

  # Rounds each variant's share of 100 proportionally, then corrects any
  # rounding drift on the last variant so the total is always exactly 100.
  def rebalance_weights(variants)
    total = variants.sum { |variant| variant[:weight] }
    weights = total.positive? ? proportional_weights(variants, total) : even_weights(variants.size)
    weights[-1] += 100 - weights.sum

    variants.each_with_index.map { |variant, index| variant.merge(weight: weights[index]) }
  end

  def proportional_weights(variants, total)
    variants.map { |variant| (variant[:weight] / total * 100).round }
  end

  def even_weights(count)
    Array.new(count, 100 / count)
  end

  def slugify(value, fallback:)
    slug = value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    slug.presence || slugify(fallback, fallback: "option")
  end

  def unique_within(name, used_names)
    return name unless used_names.include?(name)

    suffix = 2
    suffix += 1 while used_names.include?("#{name}_#{suffix}")
    "#{name}_#{suffix}"
  end

  def unique_experiment_name(name)
    return name unless Experiment.exists?(name: name)

    suffix = 2
    suffix += 1 while Experiment.exists?(name: "#{name}_#{suffix}")
    "#{name}_#{suffix}"
  end
end
