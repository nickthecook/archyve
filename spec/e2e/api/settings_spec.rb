RSpec.describe "settings", type: :system do
  let(:call) { get("/v1/settings") }

  it "returns 200" do
    expect(call.code).to eq(200)
  end

  it "contains items" do
    expect(call.parsed_body["settings"]).not_to be_empty
  end

  it "returns valid settings" do
    expect(call).to match_response_schema("settings")
  end

  describe "/v1/setting/:key" do
    let(:setting_key) { get("/v1/settings").parsed_body["settings"].first["key"] }

    let(:call) { get("/v1/settings/#{setting_key}") }

    it "returns 200" do
      expect(call.code).to eq(200)
    end

    it "returns a valid setting" do
      expect(call).to match_response_schema("setting")
    end
  end
end
