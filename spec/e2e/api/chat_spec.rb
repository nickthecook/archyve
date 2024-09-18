RSpec.describe "/v1/chat", :llm, :slow, type: :system do
  let(:call) { get("/v1/chat?prompt=hello") }

  it "returns 200" do
    expect(call.code).to eq(200)
  end

  it "returns a message" do
    expect(call).to match_response_schema("chat")
  end
end
