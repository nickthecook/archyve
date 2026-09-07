require "rails_helper"

RSpec.describe "Collections", type: :request do
  describe "GET /collections" do
    subject(:request) { get collections_path }

    context "when collections exist" do
      let!(:collection) { create(:collection, name: "Handbook") }

      it "renders them" do
        request
        expect(response.body).to include("Handbook")
      end
    end

    context "when a document has no active membership" do
      before { create(:document) }

      it "counts it under Unsorted" do
        request
        expect(response.body).to include("Unsorted")
      end
    end
  end

  describe "GET /collections/:slug" do
    subject(:request) { get collection_path(collection) }

    let(:collection) { create(:collection, name: "House") }

    context "when the collection has an active document" do
      let(:document) { create(:document) }

      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "lists the document" do
        request
        expect(response.body).to include(document.title)
      end
    end

    context "when the collection is empty" do
      it "renders an empty state" do
        request
        expect(response.body).to include("No documents in this collection yet.")
      end
    end
  end

  describe "POST /collections/:slug/documents" do
    subject(:request) { post collection_documents_path(collection), params: { document_ids: } }

    let(:collection) { create(:collection, name: "House") }
    let(:document) { create(:document) }

    context "when adding a document not yet in the collection" do
      let(:document_ids) { [document.id] }

      it "adds it as a manual membership" do
        expect { request }.to change { collection.documents.count }.by(1)
      end

      it "redirects with a confirmation" do
        request
        expect(flash[:notice]).to include("Added 1 document")
      end
    end

    context "when adding a document already in the collection" do
      let(:document_ids) { [document.id] }

      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "is a no-op (idempotent), not an error" do
        expect { request }.not_to change { collection.documents.count }
      end
    end

    context "when nothing is selected" do
      let(:document_ids) { [] }

      it "says so rather than pretending to add" do
        request
        expect(flash[:notice]).to eq("No documents selected.")
      end
    end
  end

  describe "DELETE /collections/:slug/documents/:id" do
    subject(:request) { delete collection_document_path(collection, document) }

    let(:collection) { create(:collection) }
    let(:document) { create(:document) }

    context "when the membership is manual" do
      let!(:membership) { create(:collection_membership, collection:, document:, origin: "manual") }

      it "removes the document from the collection" do
        expect { request }.to change { membership.reload.active? }.from(true).to(false)
      end
    end

    context "when the membership is source-fed" do
      before { create(:collection_membership, :feed, collection:, document:) }

      it "refuses and surfaces why" do
        request
        expect(flash[:alert]).to include("source")
      end
    end
  end

  describe "POST /collections" do
    subject(:request) { post collections_path, params: { collection: { name: } } }

    context "when the name is valid" do
      let(:name) { "Design Docs" }

      it "creates the collection" do
        expect { request }.to change(Collection, :count).by(1)
      end

      it "redirects to the index" do
        request
        expect(response).to redirect_to(collections_path)
      end
    end

    context "when the name is blank" do
      let(:name) { "" }

      it "does not create a collection" do
        expect { request }.not_to change(Collection, :count)
      end

      it "redirects back with the error surfaced" do
        request
        expect(flash[:alert]).to be_present
      end
    end
  end
end
