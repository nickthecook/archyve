require "rails_helper"

RSpec.describe Embeddings::Embed do
  let(:vector) { Array.new(768) { 0.1 } }
  let(:llm_result) { instance_double(RubyLLM::Embedding, vectors: vector) }

  # Stubbed at the context, not at RubyLLM.embed: the whole point of the
  # rewiring is that each server embeds through its own config rather than the
  # process-wide one, so that is the seam worth pinning.
  let(:context) { instance_double(RubyLLM::Context, embed: llm_result) }

  let!(:model) { create(:embedding_model, inference_server: server) }
  let(:server) { create(:ollama_server, name: "tensor") }

  before { allow_any_instance_of(InferenceServers::Ollama).to receive(:llm_context).and_return(context) }

  describe ".document" do
    let(:result) { described_class.document("how it works") }

    it "prefixes the text with the search_document task" do
      result
      expect(context).to have_received(:embed).with(
        "search_document: how it works",
        model: model.name,
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
      expect(context).to have_received(:embed).with(
        "search_query: how it works",
        model: model.name,
        provider: :ollama,
        assume_model_exists: true
      )
    end
  end

  describe "with a model not trained on the task prefixes" do
    let!(:model) do
      create(:embedding_model, inference_server: server, name: "text-embedding-3-small", dimensions: 1536)
    end
    let(:server) { create(:azure_server) }
    let(:vector) { Array.new(1536) { 0.1 } }

    before { allow_any_instance_of(InferenceServers::Azure).to receive(:llm_context).and_return(context) }

    it "sends a document unprefixed" do
      described_class.document("how it works")
      expect(context).to have_received(:embed).with("how it works", hash_including(model: "text-embedding-3-small"))
    end

    it "sends a query unprefixed" do
      described_class.query("how it works")
      expect(context).to have_received(:embed).with("how it works", hash_including(model: "text-embedding-3-small"))
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

  describe "with nothing configured" do
    # A fresh install has no inference server at all. That has to fail with
    # something that says so, not a NoMethodError on nil.
    let!(:model) { nil }

    it "raises NotConfigured" do
      expect { described_class.document("x") }.to raise_error(described_class::NotConfigured, /no embedding model/)
    end
  end

  describe "when the model is disabled" do
    let!(:model) { create(:embedding_model, inference_server: server, enabled: false) }

    it "raises NotConfigured" do
      expect { described_class.document("x") }.to raise_error(described_class::NotConfigured)
    end
  end
end
