require "rails_helper"

RSpec.describe "Search", type: :request do
  describe "GET /search" do
    subject(:request) { get search_path, params: }

    # Declared first so it exists before any embedding does — InferenceModel
    # refuses a new embedder once the corpus holds vectors another one produced.
    # Its name matches what the :embedding factory stamps on each vector, which
    # is what the retrieval filter matches on.
    let!(:embedding_model) { create(:embedding_model) }

    # Only the network hop to Ollama is stubbed; the nearest-neighbor query and
    # the collection scope join run for real against the test database.
    before { allow(Embeddings::Embed).to receive(:query).and_return(Array.new(Embedding::DIMENSIONS) { 0.1 }) }

    let(:collection) { create(:collection, name: "Reports") }
    let(:inside) { create(:document, title: "Inside Report") }
    let(:outside) { create(:document, title: "Outside Memo") }

    let(:other_collection) { create(:collection, name: "Memos") }

    before do
      create(:embedding, chunk: create(:chunk, document: inside))
      create(:embedding, chunk: create(:chunk, document: outside))
      create(:collection_membership, collection:, document: inside, origin: "manual")
      create(:collection_membership, collection: other_collection, document: outside, origin: "manual")
      create(:collection_user, collection:, user: current_user)
      create(:collection_user, collection: other_collection, user: current_user)
    end

    # Reaching the document is the same for everyone; inspecting how retrieval
    # chunked it is a curator's tool. See Views::Documents::Access.
    context "when a result's source can't hand out a followable link" do
      let(:params) { { q: "anything" } }
      let(:inside) { create(:document, :with_file, title: "Inside Report") }

      context "when signed in as a visitor" do
        # Signing in again replaces current_user, so the grant has to follow —
        # a reader with no grant retrieves nothing at all now.
        before do
          sign_in(create(:user))
          create(:collection_user, collection:, user: current_user)
        end

        it "offers the document as a download" do
          request
          expect(response.body).to include("/documents/#{inside.id}/download")
        end

        it "does not offer the chunk view" do
          request
          expect(response.body).not_to include("Inspect chunks")
        end
      end

      context "when signed in as a curator" do
        it "also offers the chunk view" do
          request
          expect(response.body).to include("Inspect chunks")
        end
      end
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

    context "when unscoped" do
      let(:params) { { q: "anything" } }

      it "searches every collection they can read" do
        request
        expect(response.body).to include("Inside Report").and include("Outside Memo")
      end
    end

    # Retrieval is where access control is enforced. Everything below is about
    # what a query can reach, not what the UI shows.
    context "when a document sits in a collection they cannot read" do
      let(:params) { { q: "anything" } }

      before { CollectionUser.find_by!(collection: other_collection, user: current_user).destroy }

      it "does not return it" do
        request
        expect(response.body).not_to include("Outside Memo")
      end

      it "still returns what they can read" do
        request
        expect(response.body).to include("Inside Report")
      end
    end

    # A document in no collection is reachable through no grant, so it is
    # outside everyone's corpus but an admin's.
    context "when a document is in no collection at all" do
      let(:params) { { q: "anything" } }
      let!(:unfiled) { create(:document, title: "Unfiled Draft") }

      before { create(:embedding, chunk: create(:chunk, document: unfiled)) }

      it "is not retrievable by a curator" do
        request
        expect(response.body).not_to include("Unfiled Draft")
      end

      context "when signed in as an admin" do
        before { sign_in(create(:user, :admin)) }

        it "is retrievable, since admins are unrestricted" do
          request
          expect(response.body).to include("Unfiled Draft")
        end
      end
    end

    # Erroring would confirm the collection exists; dropping the slug does not.
    context "when scoped to a collection they cannot read" do
      let(:hidden) { create(:collection, name: "Restricted") }
      let(:params) { { q: "anything", c: hidden.slug } }

      before do
        create(:collection_membership, collection: hidden, document: outside, origin: "manual")
      end

      it "does not name it" do
        request
        expect(response.body).not_to include("Restricted")
      end

      it "returns nothing from it" do
        request
        expect(response.body).not_to include("Outside Memo")
      end
    end

    context "when scoped by document id to one they cannot read" do
      let(:hidden_document) { create(:document, title: "Secret Memo") }
      let(:params) { { q: "anything", doc: hidden_document.id } }

      before { create(:embedding, chunk: create(:chunk, document: hidden_document)) }

      it "does not leak the title through the scope label" do
        request
        expect(response.body).not_to include("Secret Memo")
      end
    end
  end
end
