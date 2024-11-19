RSpec.describe "/v1/chat", :api, :llm, :slow, type: :system do
  let(:call) { api_get("/v1/chat?prompt=hello") }
  let(:conversation_id) { @call.parsed_body["conversation"] }
  let(:conversation_call) { api_get("/v1/conversations/#{conversation_id}") }
  let(:messages_call) { api_get("/v1/conversations/#{conversation_id}/messages") }

  before do
    @call ||= call
  end

  it "returns 200" do
    expect(@call.code).to eq(200)
  end

  it "returns a message" do
    expect(@call).to match_response_schema("chat")
  end

  it "creates a conversation in the database" do
    expect(conversation_call.code).to eq(200)
  end

  it "creates messages in the database" do
    expect(messages_call.parsed_body["messages"][0]).to include(
      "content" => "hello",
      "author_type" => "User"
    )
    expect(messages_call.parsed_body["messages"][1]).to include(
      "author_type" => "ModelConfig"
    )
  end
end
