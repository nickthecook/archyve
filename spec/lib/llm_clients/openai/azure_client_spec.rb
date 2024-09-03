RSpec.describe LlmClients::Openai::AzureClient do
  subject { described_class.new(endpoint:, api_key:, api_version:, embedding_model:, model:, temperature:) }

  let(:endpoint) { "http://example.com/nope" }
  let(:api_key) { "1234" }
  let(:embedding_model) { "embedding-3-large" }
  let(:model) { "test-gpt-35" }
  let(:api_version) { "2024-02-15-preview" }
  let(:temperature) { 0.1 }
  let(:openai) { instance_double(OpenAI::Client, chat: chat_response, embeddings: embeddings_response) }
  let(:chat_response) do
    {
      "choices" => [
        {
          "message" => { "content" => "Einstein" },
        },
      ],
      "usage" => { "total_tokens" => 1 },
    }
  end
  let(:embeddings_response) do
    {
      "data" => [
        {
          "embedding" => [0.1, 0.2, 0.3],
        },
      ],
    }
  end

  before do
    allow(OpenAI::Client).to receive(:new).and_return(openai)
  end

  describe "#embed" do
    let(:content) { "Any old content" }
    let(:result) { subject.embed(content) }

    it "returns an the" do
      expect(result['embedding']).to eq([0.1, 0.2, 0.3])
    end
  end

  describe "#complete" do
    let(:result) { subject.complete(content) }
    let(:content) { 'General relativity was conceived by' }
    let(:expected_complete_params) do
      {
        parameters: {
          model: "test-gpt-35",
          messages: [{ role: "user", content: }],
          temperature: 0.1,
        },
      }
    end
    let(:streamed_result) do
      response = ""

      subject.complete(content) do |tokens|
        response << tokens
      end

      response
    end

    it "returns a string" do
      expect(result).to be_a(String)
    end

    it "identifies 'Einstein' within completion" do
      expect(result).to eq("Einstein")
    end

    it "calls the OpenAI client with the correct messages" do
      subject.complete(content)
      expect(openai).to have_received(:chat).with(expected_complete_params)
    end

    it "streams the same response as it returns" do
      expect(result).to eq(streamed_result)
    end

    context "when it gets throttled by the server" do
      before do
        allow(openai).to receive(:chat).and_raise(Faraday::TooManyRequestsError)
        allow(Setting).to receive(:get).and_call_original
        allow(Setting).to receive(:get).with("openai_client_retry_wait_time_s", anything).and_return(0)
        allow(Setting).to receive(:get).with("openai_client_retry_attempts", anything).and_return(1)
      end

      it "raises a RetryableError" do
        expect { subject.complete(content) }.to raise_error(LlmClients::RetryableError)
      end
    end
  end

  describe "#chat" do
    let(:message) { create(:message, content:, conversation:) }
    let(:content) { "Any old content" }
    let(:conversation) { create(:conversation, messages: []) }
    let(:result) { subject.chat(message).dig("choices", 0, "message", "content") }
    let(:streamed_result) do
      response = ""

      subject.complete(content) do |tokens|
        response << tokens
      end

      response
    end

    it "identifies 'scatter' in the answer" do
      expect(result).to eq("Einstein")
    end

    it "streams the same response as it returns" do
      expect(result).to eq(streamed_result)
    end
  end
end
