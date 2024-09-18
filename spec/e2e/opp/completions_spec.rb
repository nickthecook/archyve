RSpec.describe "opp/v1/chat/completions", :chat, :llm, :now, :opp, :slow, type: :system do
  let(:call) { opp_post("/v1/chat/completions", payload) }
  let(:payload) do
    {
      model: "llama3.1:latest",
      stream: false,
      messages: [
        {
          role: "user",
          content: "tetsaroo",
        },
      ],
      max_tokens: 50,
    }
  end

  it "returns a chat response" do
    expect(call.code).to eq(200)
    expect(call).to match_response_schema("opp/completion")
  end
end
