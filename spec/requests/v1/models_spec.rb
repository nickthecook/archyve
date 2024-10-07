require 'rails_helper'

RSpec.describe "V1::Models" do
  let!(:model_config) { create(:model_config, name: "Sir Mixalot", model: "mixalot:99b") }

  include_context "when api client is authenticated"

  describe "GET /v1/models" do
    let(:params) { nil }

    before do
      get "/v1/models", params:, headers:
    end

    it "returns a list of models" do
      expect(response.parsed_body).to eq({
        "models" => [
          {
            "id" => model_config.id,
            "model" => model_config.model,
            "name" => model_config.name,
            "temperature" => model_config.temperature,
          },
        ],
      })
    end
  end

  describe "GET /v1/models/[:id]" do
    let(:name) { CGI.escape("Sir Mixalot") }

    before do
      get "/v1/models/#{name}", headers:
    end

    it "returns the model info" do
      expect(response.parsed_body).to eq({
        "model" => {
          "id" => model_config.id,
          "model" => model_config.model,
          "name" => model_config.name,
          "temperature" => model_config.temperature,
        },
      })
    end

    context "when asking for the model by model string" do
      let(:name) { "mixalot:99b" }

      it "returns the model info" do
        expect(response.parsed_body).to eq({
          "model" => {
            "id" => model_config.id,
            "model" => model_config.model,
            "name" => model_config.name,
            "temperature" => model_config.temperature,
          },
        })
      end
    end

    context "when asking for the model by id" do
      let(:name) { model_config.id }

      it "returns the model info" do
        expect(response.parsed_body).to eq({
          "model" => {
            "id" => model_config.id,
            "model" => model_config.model,
            "name" => model_config.name,
            "temperature" => model_config.temperature,
          },
        })
      end
    end
  end
end
