RSpec.describe "/v1/version", :api, type: :system do
  let(:call) { api_get("/v1/version") }

  it "returns 200" do
    expect(call.code).to eq(200)
  end

  it "returns a valid version" do
    expect(call).to match_response_schema("version")
  end
end
