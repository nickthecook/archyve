RSpec.describe "models", :api, type: :system do
  describe "/v1/models" do
    let(:call) { api_get("/v1/models") }

    it "returns 200" do
      expect(call.code).to eq(200)
    end

    it "contains items" do
      expect(call.parsed_body["models"]).not_to be_empty
    end

    it "returns a list of models" do
      expect(call).to match_response_schema("models")
    end

    describe "/v1/models/:id" do
      let(:model_id) { api_get("/v1/models").parsed_body["models"].last["id"] }

      let(:call) { api_get("/v1/models/#{model_id}") }

      it "returns 200" do
        expect(call.code).to eq(200)
      end

      it "returns a model" do
        expect(call).to match_response_schema("model")
      end
    end
  end
end
