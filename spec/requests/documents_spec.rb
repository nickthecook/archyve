require "rails_helper"

RSpec.describe "Documents", type: :request do
  describe "GET /documents/:id" do
    subject(:request) { get document_path(document), headers: { "HTTP_REFERER" => referer } }

    let(:document) { create(:document, title: "Blueprint") }

    context "when arrived from a collection" do
      let(:collection) { create(:collection, name: "Handbook") }
      let(:referer) { "http://www.example.com#{collection_path(collection)}" }

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
