require "net/http"
require "json"

# Generates variant copy via the Gemini API, called once at configuration
# time only -- never on the assignment path (see DESIGN.md "The LLM
# decision"). Never raises: any failure falls back to the caller's default.
class VariantContentGenerator
  ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent".freeze
  REQUEST_TIMEOUT_SECONDS = 6

  Result = Struct.new(:content, :source, keyword_init: true)

  def self.call(prompt:, fallback:)
    new(prompt:, fallback:).call
  end

  def initialize(prompt:, fallback:)
    @prompt = prompt
    @fallback = fallback
  end

  def call
    generated = fetch_generated_text
    return Result.new(content: generated, source: "llm") if generated.present?

    Result.new(content: fallback, source: "llm_fallback")
  rescue StandardError => e
    Rails.logger.error("VariantContentGenerator failed (#{e.class}): #{e.message}")
    Result.new(content: fallback, source: "llm_fallback")
  end

  private

  attr_reader :prompt, :fallback

  def fetch_generated_text
    api_key = ENV["GEMINI_API_KEY"]
    return nil if api_key.blank? || prompt.blank?

    response = post_to_gemini(api_key)
    return nil unless response.is_a?(Net::HTTPSuccess)

    extract_text(JSON.parse(response.body))
  end

  def post_to_gemini(api_key)
    uri = URI("#{ENDPOINT}?key=#{api_key}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = REQUEST_TIMEOUT_SECONDS
    http.read_timeout = REQUEST_TIMEOUT_SECONDS

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = { contents: [ { parts: [ { text: wrapped_prompt } ] } ] }.to_json

    http.request(request)
  end

  # A short, freeform prompt like "free shipping" reads as a question to
  # Gemini, not a copywriting brief -- it'll answer conversationally instead
  # of writing copy. Wrapping it as an explicit instruction fixes that
  # regardless of how terse or detailed the caller's prompt is.
  def wrapped_prompt
    "Write one short, punchy piece of marketing copy (a headline or CTA, under 12 " \
      "words) for: \"#{prompt}\". Return ONLY that copy as plain text -- no quotes, " \
      "no markdown, no headings, no explanation, no alternatives."
  end

  def extract_text(body)
    clean(body.dig("candidates", 0, "content", "parts", 0, "text"))
  end

  # Defense in depth alongside the prompt instructions above: even if Gemini
  # ignores them, only ever use the first line and strip common markdown/
  # quoting artifacts, so a stray "**" or a wall of text never reaches a UI.
  def clean(text)
    return nil if text.blank?

    text.strip.lines.first.to_s.strip
      .gsub("**", "")
      .sub(/\A#+\s*/, "")
      .gsub(/\A["'“”]+|["'“”]+\z/, "")
      .presence
  end
end
