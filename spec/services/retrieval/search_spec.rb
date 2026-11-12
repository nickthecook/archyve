require "rails_helper"

RSpec.describe Retrieval::Search do
  describe "#call" do
    subject(:search) { described_class.new(corpus: Retrieval::Corpus.new(user:, scope:)) }

    let(:result) { search.call(queries) }

    let(:user) { create(:user) }
    let(:scope) { nil }
    let(:queries) { "anything" }

    # Declared first so it exists before any embedding does — InferenceModel
    # refuses a new embedder once the corpus holds vectors another one produced.
    let!(:embedding_model) { create(:embedding_model) }

    let(:collection) { create(:collection) }
    let(:document) { create(:document, title: "Handbook") }

    before do
      create(:embedding, chunk: create(:chunk, document:))
      create(:collection_membership, collection:, document:, origin: "manual")
      create(:collection_user, collection:, user:)
      allow(Embeddings::Embed).to receive(:query).and_return(Array.new(768) { 0.1 })
    end

    context "when the query matches something they may read" do
      it "returns it" do
        expect(result.hits.map { it.document.title }).to eq(["Handbook"])
      end

      it "did not fail" do
        expect(result).not_to be_failed
      end

      it "numbers the hit so the model can cite it" do
        expect(result.hits.first.handle).to eq(1)
      end
    end

    context "with a 1536-dimension embedding model" do
      let!(:embedding_model) { create(:embedding_model, name: "text-embedding-3-small", dimensions: 1536) }

      before do
        Embedding.delete_all
        create(:embedding, chunk: create(:chunk, document:), embedding_model: embedding_model.name,
          vector: Array.new(1536) { rand })
        allow(Embeddings::Embed).to receive(:query).and_return(Array.new(1536) { 0.1 })
      end

      it "searches the 1536 column" do
        expect(result.hits.map { it.document.title }).to eq(["Handbook"])
      end
    end

    context "with several queries" do
      let(:queries) { ["one", "two"] }

      it "returns each chunk once, however many queries found it" do
        expect(result.hits.size).to eq(1)
      end

      it "reports the pool the hits were chosen from" do
        expect(result.candidate_count).to eq(1)
      end
    end

    context "when the queries are all blank" do
      let(:queries) { ["", "   "] }

      it "does not reach the embedding model at all" do
        result
        expect(Embeddings::Embed).not_to have_received(:query)
      end

      it "found nothing rather than failing" do
        expect(result).to be_found_nothing
      end
    end

    # The distinction the Outcome type exists for: a model handed an empty list
    # will say the archive doesn't cover something. It must only ever say that
    # when retrieval actually ran.
    context "when nothing in the corpus is readable by them" do
      let(:user) { create(:user) }

      before { CollectionUser.find_by!(collection:, user:).destroy }

      it "found nothing" do
        expect(result).to be_found_nothing
      end

      it "did not fail" do
        expect(result).not_to be_failed
      end
    end

    context "when no embedding model is configured" do
      before { embedding_model.update!(enabled: false) }

      it "fails rather than returning nothing" do
        expect(result).to be_failed
      end

      it "says there is nothing configured yet" do
        expect(result.failure.kind).to eq(:not_configured)
      end

      it "is not mistaken for an empty archive" do
        expect(result).not_to be_found_nothing
      end
    end

    context "when the embedding server can't be reached" do
      before { allow(Embeddings::Embed).to receive(:query).and_raise(Faraday::ConnectionFailed, "down") }

      it "fails rather than returning nothing" do
        expect(result).to be_failed
      end

      it "distinguishes an unreachable host from an unconfigured one" do
        expect(result.failure.kind).to eq(:unreachable)
      end

      it "names the server, so the message can say what to go and check" do
        expect(result.failure.server_name).to eq(embedding_model.inference_server.name)
      end

      # Starts green on purpose: a never-checked server is already not
      # reachable, so asserting from that state would pass without the mark.
      it "marks the server unreachable" do
        embedding_model.inference_server.mark_reachable!
        result
        expect(embedding_model.inference_server.reload).not_to be_reachable
      end
    end

    context "when the search succeeds" do
      it "marks the server reachable" do
        result
        expect(embedding_model.inference_server.reload).to be_reachable
      end
    end

    # Fusion is local SQL. Its failures say nothing about the host, so the mark
    # sits between embedding and fusion rather than after both.
    context "when fusion blows up after the server answered" do
      before { allow(Retrieval::Fuse).to receive(:call).and_raise(NoMethodError, "undefined method") }

      it "leaves the server reachable" do
        result
        expect(embedding_model.inference_server.reload).to be_reachable
      end
    end

    context "when scoped to a collection they cannot read" do
      let(:hidden) { create(:collection, name: "Restricted") }
      let(:scope) { Retrieval::Scope.from_params({ c: [hidden.slug] }, user:) }

      before { create(:collection_membership, collection: hidden, document:, origin: "manual") }

      it "returns nothing from it" do
        expect(result.hits).to be_empty
      end

      it "does not leak its name through the label" do
        expect(scope.label).not_to include("Restricted")
      end
    end
  end
end
