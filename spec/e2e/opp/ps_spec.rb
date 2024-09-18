RSpec.describe "opp/api/ps", :opp, type: :system do
  let(:call) { opp_get("/api/ps") }

  it "returns 200" do
    expect(call.code).to eq(200)
  end

  it "returns the list of loaded models" do
    expect(call).to match_response_schema("opp/ps")
  end
end
