require 'rails_helper'

RSpec.describe "V1::Models" do
  let!(:model_config) { create(:model_config) }

  include_context "authenticated api client"

  describe "GET /index" do
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
end
