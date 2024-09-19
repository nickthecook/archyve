RSpec.describe "opp/v1/chat/completions", :chat, :llm, :opp, :slow, type: :system do
  let(:call) { opp_post("/v1/chat/completions", payload) }

  context "when client is Open WebUI" do
    let(:payload) do
      {
        model: "llama3.1:latest",
        stream: false,
        messages: [
          {
            role: "user",
            content: "Tell me about Skippy Dare.",
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

  context "when client is Huggingface ChatUI" do
    let(:payload) do
      {
        model: "llama3.1:latest",
        stream: true,
        messages: [
          {
            role: "system",
            content: "",
          },
          {
            role: "user",
            content: [
              {
                text: "Tell me about Skippy Dare.",
                type: "text",
              },
            ],
          },
        ],
      }
    end

    it "returns a chat response" do
      expect(call.code).to eq(200)
      expect(call).to have_chunks_matching_schema("opp/completion_chunk")
    end
  end
end
