RSpec.describe "opp/api/version", :opp, type: :system do
  let(:call) { opp_get("/api/version") }

  it "returns 200" do
    expect(call.code).to eq(200)
  end

  it "returns a version" do
    expect(call.parsed_body["version"]).to be_a(String)
  end
end
