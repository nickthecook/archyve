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
    parsed_response_chunks = call.body.lines.map { |l| JSON.parse(l) }
    last_chunk = parsed_response_chunks.pop

    expect(parsed_response_chunks).to all(match_response_schema("opp/chat_chunk"))
    expect(last_chunk).to match_response_schema("opp/last_chat_chunk")
  end
end
