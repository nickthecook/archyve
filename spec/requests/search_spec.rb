require "rails_helper"

RSpec.describe "Search", type: :request do
  describe "GET /search" do
    subject(:request) { get search_path, params: }

    # Only the network hop to Ollama is stubbed; the nearest-neighbor query and
    # the collection scope join run for real against the test database.
    before { allow(Embeddings::Embed).to receive(:query).and_return(Array.new(Embedding::DIMENSIONS) { 0.1 }) }

    let(:collection) { create(:collection, name: "Reports") }
    let(:inside) { create(:document, title: "Inside Report") }
    let(:outside) { create(:document, title: "Outside Memo") }

    before do
      create(:embedding, chunk: create(:chunk, document: inside))
      create(:embedding, chunk: create(:chunk, document: outside))
      create(:collection_membership, collection:, document: inside, origin: "manual")
    end

    context "when scoped to a collection" do
      let(:params) { { q: "anything", c: collection.slug } }

      it "returns documents in the collection" do
        request
        expect(response.body).to include("Inside Report")
      end

      it "excludes documents outside the collection" do
        request
        expect(response.body).not_to include("Outside Memo")
      end

      it "names the active scope" do
        request
        expect(response.body).to include("In Reports")
      end
    end

    context "when unscoped (all collections)" do
      let(:params) { { q: "anything" } }

      it "searches the whole corpus" do
        request
        expect(response.body).to include("Inside Report").and include("Outside Memo")
      end
    end
  end
end
