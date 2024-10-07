require 'rails_helper'

RSpec.describe "Collections" do
  include_context "when api client is authenticated"

  let!(:collections) { create_list(:collection, 2) }

  describe "GET /collections" do
    before do
      get "/v1/collections", headers:
    end

    it "returns a list of Collections" do
      expect(response.parsed_body).to eq({
        "collections" => [
          {
            "id" => collections.first.id,
            "name" => collections.first.name,
            "slug" => collections.first.slug,
            "embedding_model_id" => collections.first.embedding_model_id,
          },
          {
            "id" => collections.second.id,
            "name" => collections.second.name,
            "slug" => collections.second.slug,
            "embedding_model_id" => collections.second.embedding_model_id,
          },
        ],
      })
    end
  end

  describe "GET /v1/collections/:id" do
    let(:id) { collections.first.id }

    before do
      get "/v1/collections/#{id}", headers:
    end

    it "returns the requested collection" do
      expect(response.parsed_body).to eq({
        "collection" => {
          "id" => id,
          "name" => collections.first.name,
          "slug" => collections.first.slug,
          "embedding_model_id" => collections.first.embedding_model_id,
        },
      })
    end

    context "when the requested collection does not exist" do
      let(:id) { 0 }

      it "returns a 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /v1/collections/:id/search" do
    let(:id) { collections.first.id }
    let(:results_double) { instance_double(Api::GenerateSearchResults, search: results) }
    let(:results) { [{ test: "search hit" }] }

    before do
      allow(Api::GenerateSearchResults).to receive(:new).and_return(results_double)

      get "/v1/collections/#{id}/search?q=testing", headers:
    end

    it "returns a list of search results" do
      expect(response.parsed_body).to eq({ "hits" => [{ "test" => "search hit" }] })
    end

    context "when query is not given" do
      before do
        get "/v1/collections/#{id}/search", headers:
      end

      it "returns a 400" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the requested collection does not exist" do
      let(:id) { 0 }

      it "returns a 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /v1/collections" do
    let(:body) { { name: "Test Collection" } }
    let(:embedding_model) { create(:model_config, embedding: true) }

    before do
      Setting.set("embedding_model", embedding_model.id)

      post "/v1/collections", params: body, headers:
    end

    it "returns the new collection info" do
      expect(response.parsed_body).to eq({
        "collection" => {
          "id" => Collection.last.id,
          "name" => body[:name],
          "slug" => Collection.last.slug,
          "embedding_model_id" => embedding_model.id,
        },
      })
    end

    it "returns 201 created" do
      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /v1/collections/:id" do
    let(:collection) { create(:collection, name: "Test Collection") }

    before do
      delete "/v1/collections/#{collection.id}", headers:
    end

    it "returns the info of the deleted collection" do
      expect(response.parsed_body).to eq({
        "collection" => {
          "id" => collection.id,
          "name" => collection.name,
          "slug" => collection.slug,
          "embedding_model_id" => collection.embedding_model_id,
        },
      })
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end
  end
end
