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
