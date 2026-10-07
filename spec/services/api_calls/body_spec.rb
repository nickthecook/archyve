require "rails_helper"

RSpec.describe ApiCalls::Body do
  describe ".summarize" do
    subject(:summary) { described_class.summarize(raw) }

    context "with JSON" do
      let(:raw) { '{"model":"qwen3","n":2}' }

      it { is_expected.to eq({ "model" => "qwen3", "n" => 2 }) }
    end

    context "with a blank body" do
      let(:raw) { "" }

      it { is_expected.to be_nil }
    end

    context "with a body that is not JSON" do
      let(:raw) { %(data: {"delta":{}}\n\n) }

      it "keeps it as a string, so a streamed response stays readable" do
        expect(summary).to eq(raw)
      end
    end

    context "with a string past the cap" do
      let(:long) { "x" * (described_class::MAX_STRING + 50) }
      let(:raw) { { content: long }.to_json }

      it "truncates it" do
        expect(summary["content"].length).to be < long.length
      end

      it "reports the original length" do
        expect(summary["content"]).to end_with("[#{long.length} chars total]")
      end
    end

    context "with an array past the cap" do
      let(:raw) { { items: Array.new(described_class::MAX_ITEMS + 10, "x") }.to_json }

      it "keeps the cap plus a marker" do
        expect(summary["items"].length).to eq(described_class::MAX_ITEMS + 1)
      end

      it "reports what it dropped" do
        expect(summary["items"].last).to eq("[10 more items]")
      end
    end

    context "with nesting" do
      let(:raw) { { a: { b: [{ c: "deep" }] } }.to_json }

      it "walks it" do
        expect(summary.dig("a", "b", 0, "c")).to eq("deep")
      end
    end
  end
end
