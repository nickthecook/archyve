require "rails_helper"

RSpec.describe "Unsorted", type: :request do
  describe "GET /unsorted" do
    subject(:request) { get unsorted_path }

    context "when a document is in no collection" do
      let!(:document) { create(:document, title: "Loose Note") }

      it "lists it" do
        request
        expect(response.body).to include("Loose Note")
      end
    end

    context "when a document is in a collection" do
      let(:document) { create(:document, title: "Filed Note") }

      before { create(:collection_membership, document:, collection: create(:collection), source: "manual") }

      it "excludes it" do
        request
        expect(response.body).not_to include("Filed Note")
      end
    end
  end

  describe "POST /unsorted/assign" do
    subject(:request) { post assign_unsorted_path, params: { collection_slug: collection.slug, document_ids: } }

    let(:collection) { create(:collection, name: "Handbook") }
    let(:document) { create(:document) }

    context "when documents are selected" do
      let(:document_ids) { [document.id] }

      it "adds them to the collection (so they leave Unsorted)" do
        expect { request }.to change { collection.documents.count }.by(1)
      end

      it "confirms the assignment" do
        request
        expect(flash[:notice]).to include("Added 1 document to Handbook")
      end
    end

    context "when nothing is selected" do
      let(:document_ids) { [] }

      it "says so" do
        request
        expect(flash[:notice]).to eq("No documents selected.")
      end
    end
  end
end
