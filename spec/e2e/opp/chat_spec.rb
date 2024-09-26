RSpec.describe "opp/api/chat", :chat, :llm, :opp, :slow, type: :system do
  let(:call) { opp_post("/api/chat", payload) }
  let(:payload) do
    {
      model: "llama3.1:8b",
      format: "",
      options: {},
      messages: [
        {
          role: "user",
          content: "Who is Skippy Dare?",
        },
      ],
    }.to_json
  end
  let(:conversations_call) { api_get("/v1/conversations") }
  let(:conversation_id) { conversations_call.parsed_body.dig("conversations", 0, "id") }
  let(:conversation_call) { api_get("/v1/conversations/#{conversation_id}") }
  let(:messages_call) { api_get("/v1/conversations/#{conversation_id}/messages") }

  # this one is so slow I've crammed all these assertions into one example
  it "returns a chat response" do
    expect(call.code).to eq(200)
    expect(call).to have_chunks_matching_schema("opp/chat_chunk", "opp/last_chat_chunk")
  end

  it "creates a conversation in the database" do
    expect(conversation_call.code).to eq(200)
  end

  it "creates messages in the database" do
    expect(messages_call.parsed_body["messages"][0]).to include(
      "content" => "Who is Skippy Dare?",
      "author_type" => "User"
    )
    expect(messages_call.parsed_body.dig("messages", 1)).to include(
      "author_type" => "ModelConfig"
    )
    expect(messages_call.parsed_body.dig("messages", 1, "content")).not_to be_empty
  end
end
