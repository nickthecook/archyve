RSpec.describe "collections", :api, type: :system do
  describe "/v1/collections" do
    let(:call) { api_get("/v1/collections") }

    it "returns 200" do
      expect(call.code).to eq(200)
    end

    it "contains items" do
      expect(call.parsed_body["collections"]).not_to be_empty
    end

    it "returns a list of collections" do
      expect(call).to match_response_schema("collections")
    end
  end

  describe "/v1/collections/:id" do
    let(:collection_id) { test_collection_id }

    let(:call) { api_get("/v1/collections/#{collection_id}") }

    it "returns 200" do
      expect(call.code).to eq(200)
    end

    it "returns a collection" do
      expect(call).to match_response_schema("collection")
    end

    describe "/v1/collections/:id/documents" do
      let(:call) { api_get("/v1/collections/#{collection_id}/documents") }

      it "returns 200" do
        expect(call.code).to eq(200)
      end

      it "contains items" do
        expect(call.parsed_body["documents"]).not_to be_empty
      end

      it "returns a list of documents" do
        expect(call).to match_response_schema("documents")
      end
    end

    describe "/v1/collections/:id/documents/:id" do
      let(:document_id) { api_get("/v1/collections/#{collection_id}/documents").parsed_body["documents"].last["id"] }

      let(:call) { api_get("/v1/collections/#{collection_id}/documents/#{document_id}") }

      it "returns 200" do
        expect(call.code).to eq(200)
      end

      it "returns a document" do
        expect(call).to match_response_schema("document")
      end

      describe "/v1/collections/:id/documents/:id/chunks" do
        let(:call) { api_get("/v1/collections/#{collection_id}/documents/#{document_id}/chunks") }

        it "returns 200" do
          expect(call.code).to eq(200)
        end

        it "contains items" do
          expect(call.parsed_body).not_to be_empty
        end

        it "returns a list of chunks" do
          expect(call).to match_response_schema("chunks")
        end
      end
    end

    describe "/v1/collections/:id/entities" do
      let(:call) { api_get("/v1/collections/#{collection_id}/entities") }

      it "returns 200" do
        expect(call.code).to eq(200)
      end

      it "contains items" do
        expect(call.parsed_body["entities"]).not_to be_empty
      end

      it "returns a list of entities" do
        expect(call).to match_response_schema("entities")
      end

      describe "/v1/collections/:id/entities/:id" do
        let(:entity_id) { api_get("/v1/collections/#{collection_id}/entities").parsed_body["entities"].last["id"] }

        let(:call) { api_get("/v1/collections/#{collection_id}/entities/#{entity_id}") }

        it "returns 200" do
          expect(call.code).to eq(200)
        end

        it "returns an entity" do
          expect(call).to match_response_schema("entity")
        end
      end
    end

    describe "/v1/collections/:id/search", :slow do
      let(:call) { api_get("/v1/collections/#{collection_id}/search?q=test") }

      it "returns 200" do
        expect(call.code).to eq(200)
      end

      it "returns search hits" do
        expect(call).to match_response_schema("search")
      end
    end
  end
end
