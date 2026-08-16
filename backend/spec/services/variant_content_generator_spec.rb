require "rails_helper"

RSpec.describe VariantContentGenerator do
  describe ".call" do
    it "falls back without making a network call when GEMINI_API_KEY is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect(Net::HTTP).not_to receive(:new)

      result = described_class.call(prompt: "Write a headline", fallback: "Default headline")

      expect(result.content).to eq("Default headline")
      expect(result.source).to eq("llm_fallback")
    end

    it "returns the generated text and source 'llm' on a successful response" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      stub_gemini_response(text: "Free shipping, zero hassle.")

      result = described_class.call(prompt: "Write a headline", fallback: "Default headline")

      expect(result.content).to eq("Free shipping, zero hassle.")
      expect(result.source).to eq("llm")
    end

    it "falls back when the API responds with a non-success status" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      response = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)

      result = described_class.call(prompt: "Write a headline", fallback: "Default headline")

      expect(result.content).to eq("Default headline")
      expect(result.source).to eq("llm_fallback")
    end

    it "falls back (never raises) when the network call times out" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::OpenTimeout)

      result = described_class.call(prompt: "Write a headline", fallback: "Default headline")

      expect(result.content).to eq("Default headline")
      expect(result.source).to eq("llm_fallback")
    end

    it "falls back when the prompt is blank" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      expect(Net::HTTP).not_to receive(:new)

      result = described_class.call(prompt: "", fallback: "Default headline")

      expect(result.source).to eq("llm_fallback")
    end
  end

  def stub_gemini_response(text:)
    body = { candidates: [ { content: { parts: [ { text: } ] } } ] }.to_json
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)
  end
end
