require "rails_helper"

RSpec.describe ApiCalls::Kind do
  describe ".for" do
    subject(:kind) { described_class.for(URI(url)) }

    context "with an OpenAI-compatible chat completion" do
      let(:url) { "http://llm.test/v1/chat/completions" }

      it { is_expected.to eq("chat") }
    end

    context "with an OpenAI-compatible model list" do
      let(:url) { "http://llm.test/v1/models" }

      it { is_expected.to eq("discovery") }
    end

    context "with Ollama's own discovery endpoints" do
      let(:url) { "http://ollama.test/api/tags" }

      it { is_expected.to eq("discovery") }
    end

    context "with an embedding call" do
      let(:url) { "http://llm.test/v1/embeddings" }

      it { is_expected.to be_nil }
    end

    context "with a Docling conversion" do
      let(:url) { "http://docling.test/v1/convert/file" }

      it { is_expected.to be_nil }
    end
  end
end
