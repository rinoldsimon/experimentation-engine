require "rails_helper"

RSpec.describe ExperimentDraftGenerator do
  describe ".call" do
    it "raises GenerationFailed when the topic is blank" do
      expect { described_class.call(topic: "") }.to raise_error(described_class::GenerationFailed, /describe/i)
    end

    it "raises GenerationFailed without a network call when GEMINI_API_KEY is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect(Net::HTTP).not_to receive(:new)

      expect { described_class.call(topic: "Increase signups") }.to raise_error(described_class::GenerationFailed, /configured/i)
    end

    it "returns a normalized draft matching the Configuration API's shape" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      stub_gemini_draft(
        name: "Newsletter Signup Test!",
        variants: [
          { name: "Control", weight: 60, content: "Subscribe to our newsletter" },
          { name: "Control", weight: 40, content: "Join 10,000+ readers" }
        ]
      )

      draft = described_class.call(topic: "Increase newsletter signups", variant_count: 2)

      expect(draft[:name]).to eq("newsletter_signup_test")
      expect(draft[:variants]).to contain_exactly(
        { name: "control", weight: 60, content: "Subscribe to our newsletter" },
        { name: "control_2", weight: 40, content: "Join 10,000+ readers" }
      )
    end

    it "rebalances weights to sum to exactly 100 when the LLM's weights don't" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      stub_gemini_draft(
        name: "test",
        variants: [
          { name: "a", weight: 10, content: "A" },
          { name: "b", weight: 10, content: "B" },
          { name: "c", weight: 10, content: "C" }
        ]
      )

      draft = described_class.call(topic: "Something", variant_count: 3)

      expect(draft[:variants].sum { |variant| variant[:weight] }).to eq(100)
    end

    it "suffixes the experiment name when it collides with an existing one" do
      create(:experiment, name: "checkout_test")
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      stub_gemini_draft(name: "checkout_test", variants: [ { name: "a", weight: 100, content: "A" } ])

      draft = described_class.call(topic: "Checkout flow", variant_count: 1)

      expect(draft[:name]).to eq("checkout_test_2")
    end

    it "raises GenerationFailed (never returns a bad draft) when the response is malformed" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      response = Net::HTTPOK.new("1.1", "200", "OK")
      allow(response).to receive(:body).and_return("not json")
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)

      expect { described_class.call(topic: "Something") }.to raise_error(described_class::GenerationFailed)
    end
  end

  def stub_gemini_draft(name:, variants:)
    text = { name:, variants: }.to_json
    body = { candidates: [ { content: { parts: [ { text: } ] } } ] }.to_json
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)
  end
end
