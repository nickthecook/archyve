require "rails_helper"

RSpec.describe Embeddings::Embed do
  let(:vector) { Array.new(Embedding::DIMENSIONS) { 0.1 } }
  let(:llm_result) { instance_double(RubyLLM::Embedding, vectors: vector) }

  before { allow(RubyLLM).to receive(:embed).and_return(llm_result) }

  describe ".document" do
    let(:result) { described_class.document("how it works") }

    it "prefixes the text with the search_document task" do
      result
      expect(RubyLLM).to have_received(:embed).with(
        "search_document: how it works",
        model: Embedding::DEFAULT_MODEL,
        provider: :ollama,
        assume_model_exists: true
      )
    end

    it "returns the embedding vector" do
      expect(result).to eq(vector)
    end
  end

  describe ".query" do
    let(:result) { described_class.query("how it works") }

    it "prefixes the text with the search_query task" do
      result
      expect(RubyLLM).to have_received(:embed).with(
        "search_query: how it works",
        model: Embedding::DEFAULT_MODEL,
        provider: :ollama,
        assume_model_exists: true
      )
    end
  end

  describe "dimension guard" do
    context "when the model returns the wrong number of dimensions" do
      let(:vector) { [1.0, 2.0, 3.0] }

      it "raises DimensionMismatch" do
        expect { described_class.document("x") }.to raise_error(described_class::DimensionMismatch)
      end
    end
  end
end
