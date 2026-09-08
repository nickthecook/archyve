require "rails_helper"

RSpec.describe "Documents", type: :request do
  describe "POST /documents" do
    subject(:request) { post documents_path, params: }

    before { allow(ProcessDocumentJob).to receive(:perform_later) }

    let(:file) { fixture_file_upload("sample.md", "text/markdown") }

    context "when uploading into a collection" do
      let(:collection) { create(:collection, name: "Handbook") }

      before { create(:collection_user, :operator, collection:, user: current_user) }
      let(:params) { { file:, collection_slug: collection.slug } }

      it "ingests the file and files it into the collection" do
        request
        expect(collection.reload.documents.count).to eq(1)
      end

      it "redirects back to the collection" do
        request
        expect(response).to redirect_to(collection_path(collection))
      end
    end

    # The global role says they may upload; the grant says where. Without the
    # second check an operator could file documents into any collection they
    # could merely see.
    context "when uploading into a collection they can only read" do
      let(:collection) { create(:collection, name: "Handbook") }
      let(:params) { { file: fixture_file_upload("sample.md", "text/markdown"), collection_slug: collection.slug } }

      before { create(:collection_user, collection:, user: current_user) }

      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "ingests nothing" do
        expect { request }.not_to change(Document, :count)
      end
    end

    context "when uploading with no collection" do
      let(:params) { { file: } }

      it "redirects to the new document" do
        request
        expect(response).to redirect_to(Document.last)
      end
    end

    context "when no file is chosen for a collection upload" do
      let(:collection) { create(:collection) }

      before { create(:collection_user, :operator, collection:, user: current_user) }
      let(:params) { { collection_slug: collection.slug } }

      it "returns to the collection with an alert" do
        request
        expect(response).to redirect_to(collection_path(collection))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /documents/:id" do
    subject(:request) { get document_path(document), headers: { "HTTP_REFERER" => referer } }

    let(:document) { create(:document, title: "Blueprint") }

    # Reaching a document means retrieving it through a collection or managing
    # the source that produced it; these examples are about the back link, so
    # they take the simpler of the two.
    before { create(:source_user, :admin, source: document.source, user: current_user) }

    context "when arrived from a collection" do
      let(:collection) { create(:collection, name: "Handbook") }
      let(:referer) { "http://www.example.com#{collection_path(collection)}" }

      before { create(:collection_user, collection:, user: current_user) }

      it "links back to that collection" do
        request
        expect(response.body).to include("← Handbook").and include(collection_path(collection))
      end
    end

    context "when arrived from the flat documents list" do
      let(:referer) { "http://www.example.com#{documents_path}" }

      it "links back to all documents" do
        request
        expect(response.body).to include("← All documents")
      end
    end

    context "when arrived from search results" do
      let(:referer) { "http://www.example.com#{search_path}?q=hello" }

      it "links back to the search results, preserving the query" do
        request
        expect(response.body).to include("← Search results").and include("#{search_path}?q=hello")
      end
    end

    context "when there is no referrer" do
      let(:referer) { nil }

      it "falls back to the Collections section home" do
        request
        expect(response.body).to include("← Collections").and include(collections_path)
      end
    end
  end
end
