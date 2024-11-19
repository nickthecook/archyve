RSpec.describe "search", :api, :llm, :slow, type: :system do
  describe "/v1/search" do
    let(:call) { api_get("/v1/search?q=who+created+the+gnu+foundation") }

    it "returns 200" do
      expect(call.code).to eq(200)
    end

    it "contains hits" do
      expect(call.parsed_body["hits"]).not_to be_empty
    end

    it "returns valid hits" do
      expect(call).to match_response_schema("search")
    end
  end
end
