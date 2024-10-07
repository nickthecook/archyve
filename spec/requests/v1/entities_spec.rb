require 'rails_helper'

RSpec.describe "V1::Entities" do
  include_context "when api client is authenticated"

  let(:params) { nil }
  let(:collection) { create(:collection) }

  describe "GET /index" do
    context "when there are fewer than a page of entities" do
      let!(:entity_one) do
        create(
          :graph_entity,
          collection:,
          name: "Tax Avoision",
          entity_type: "Simpsons reference",
          summary: "I don't say 'evasion', I say 'avoision'.",
          summary_outdated: false
        )
      end
      let!(:entity_two) do
        create(
          :graph_entity,
          collection:,
          name: "Economic Developments",
          entity_type: "concept",
          summary: nil,
          summary_outdated: true
        )
      end

      before do
        get "/v1/collections/#{collection.id}/entities", params:, headers:
      end

      it "returns 200" do
        expect(response).to have_http_status :ok
      end

      it "returns the correct number of entities" do
        expect(response.parsed_body["entities"].count).to eq(2)
      end

      it "returns the correct entities" do
        expect(response.parsed_body["entities"].first).to eq({
          "id" => entity_one.id,
          "name" => entity_one.name,
          "entity_type" => entity_one.entity_type,
          "summary" => entity_one.summary,
          "summary_outdated" => false,
          "vector_id" => entity_one.vector_id,
          "created_at" => entity_one.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "updated_at" => entity_one.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "collection" => collection.id,
        })
        expect(response.parsed_body["entities"].last).to eq({
          "id" => entity_two.id,
          "name" => entity_two.name,
          "entity_type" => entity_two.entity_type,
          "summary" => nil,
          "summary_outdated" => true,
          "vector_id" => entity_two.vector_id,
          "created_at" => entity_two.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "updated_at" => entity_two.updated_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
          "collection" => collection.id,
        })
      end

      it "includes paging info" do
        expect(response.parsed_body["page"]).to eq({
          "page" => 1,
          "items" => 20,
          "total" => 2,
          "pages" => 1,
          "in" => 2,
        })
      end
    end

    context "when there are more than a page of entities" do
      let(:params) { { count: 5 } }

      before do
        create_list(:graph_entity, 10, collection:)

        get "/v1/collections/#{collection.id}/entities", params:, headers:
      end

      it "returns the requested number of entities" do
        expect(response.parsed_body["entities"].count).to eq(5)
      end

      it "includes paging info" do
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
