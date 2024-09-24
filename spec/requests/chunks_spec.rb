require 'rails_helper'

RSpec.describe "Chunks" do
  include_context "authenticated api client"

  let(:params) { nil }
  let(:collection) { create(:collection) }
  let(:document) { create(:document, collection:) }

  describe "GET /index" do
    context "when there are fewer than a page of chunks" do
      let!(:chunk_one) { create(:chunk, document:) }
      let!(:chunk_two) { create(:chunk, document:) }

      before do
        get "/v1/collections/#{collection.id}/documents/#{document.id}/chunks", params:, headers:
      end

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "returns two chunks" do
        expect(response.parsed_body["chunks"].count).to eq(2)
      end

      it "returns the correct chunks" do
        expect(response.parsed_body["chunks"].first).to eq({
          "id" => chunk_one.id,
          "document" => chunk_one.document_id,
          "content" => chunk_one.content,
          "embedding_content" => chunk_one.embedding_content,
          "entities_extracted" => chunk_one.entities_extracted,
          "vector_id" => chunk_one.vector_id,
          "created_at" => chunk_one.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "updated_at" => chunk_one.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        })
        expect(response.parsed_body["chunks"].second).to eq({
          "id" => chunk_two.id,
          "document" => chunk_two.document_id,
          "content" => chunk_two.content,
          "embedding_content" => chunk_two.embedding_content,
          "entities_extracted" => chunk_two.entities_extracted,
          "vector_id" => chunk_two.vector_id,
          "created_at" => chunk_two.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "updated_at" => chunk_two.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        })
      end

      it "returns paging info" do
        expect(response.parsed_body["page"]).to eq({
          "page" => 1,
          "items" => 20,
          "total" => 2,
          "pages" => 1,
          "in" => 2,
        })
      end
    end

    context "when there are more than a page of chunks" do
      let(:params) { { count: 5 } }

      before do
        create_list(:chunk, 10, document:)

        get "/v1/collections/#{collection.id}/documents/#{document.id}/chunks", params:, headers:
      end

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the correct number of chunks" do
        expect(response.parsed_body["chunks"].count).to eq(5)
      end

      it "returns the correct paging info" do
        expect(response.parsed_body["page"]).to eq({
          "page" => 1,
          "items" => 5,
          "total" => 10,
          "pages" => 2,
          "in" => 5,
        })
      end
    end
  end
end
