require 'rails_helper'

RSpec.describe "V1::Settings" do
  include_context "authenticated api client"

  let!(:settings) { create_list(:setting, 2) }

  describe "GET /v1/settings" do
    before do
      get "/v1/settings", headers:
    end

    it "returns key and value for all settings in the system" do
      expect(response.parsed_body).to eq({
        "settings" => [
          { "key" => settings.first.key, "value" => settings.first.value },
          { "key" => settings.second.key, "value" => settings.second.value },
        ],
      })
    end
  end

  describe "GET /v1/settings/[:id]" do
    let(:key) { settings.first.key }

    before do
      get "/v1/settings/#{key}", headers:
    end

    it "returns the requested setting" do
      expect(response.parsed_body).to eq({
        "setting" => { "key" => settings.first.key, "value" => settings.first.value },
      })
    end

    context "when the setting does not exist" do
      let(:key) { "key_x" }

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
