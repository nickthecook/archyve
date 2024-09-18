RSpec.describe "opp/api/tags", :opp, type: :system do
  let(:call) { opp_get("/api/tags") }

  it "returns 200" do
    expect(call.code).to eq(200)
  end

  it "returns models" do
    expect(call).to match_response_schema("opp/tags")
  end
end
