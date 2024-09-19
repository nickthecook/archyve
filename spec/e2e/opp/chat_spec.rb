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

  # this one is so slow I've crammed all these assertions into one example
  it "returns a chat response" do
    expect(call.code).to eq(200)
    expect(call).to have_chunks_matching_schema("opp/chat_chunk", "opp/last_chat_chunk")
  end
end
