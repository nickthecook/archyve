require 'rails_helper'

RSpec.describe "Documents" do
  include_context "authenticated api client"

  let(:collection) { create(:collection) }
  let!(:document) { create(:document, collection:) }

  describe "GET /v1/collections/:id/documents" do
    before do
      get "/v1/collections/#{collection.id}/documents", headers:
    end

    it "returns the list of documents" do
      expect(response.parsed_body).to eq({
        "documents" => [
          {
            "id" => document.id,
            "collection_id" => collection.id,
            "user_id" => document.user_id,
            "filename" => document.filename,
            "state" => document.state,
            "vector_id" => document.vector_id,
            "chunking_profile_id" => document.chunking_profile_id,
          },
        ],
      })
    end

    it "returns ok" do
      expect(response).to have_http_status(:ok)
    end

    context "when the collection does not exist" do
      before do
        get "/v1/collections/0/documents", headers:
      end

      it "returns a 404" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns an error message" do
        expect(response.parsed_body["error"]).to eq("Collection not found")
      end
    end
  end

  describe "GET /v1/collections/:collection_id/documents/:id" do
    before do
      get "/v1/collections/#{collection.id}/documents/#{document.id}", headers:
    end

    it "returns ok" do
      expect(response).to have_http_status(:ok)
    end

    it "returns the document" do
      expect(response.parsed_body).to eq({
        "document" => {
          "id" => document.id,
          "collection_id" => collection.id,
          "user_id" => document.user_id,
          "filename" => document.filename,
          "state" => document.state,
          "vector_id" => document.vector_id,
          "chunking_profile_id" => document.chunking_profile_id,
        },
      })
    end

    context "when the document does not exist" do
      before do
        get "/v1/collections/#{collection.id}/documents/0", headers:
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns an error message" do
        expect(response.parsed_body["error"]).to eq("Document not found")
      end
    end

    context "when the collection does not exist" do
      before do
        get "/v1/collections/0/documents/#{document.id}", headers:
      end

      it "returns a 404" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns an error message" do
        expect(response.parsed_body["error"]).to eq("Collection not found")
      end
    end
  end
end
