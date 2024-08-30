RSpec.describe LlmClients::Openai::AzureClient do
  subject { described_class.new(endpoint:, api_key:, api_version:, embedding_model:, model:, temperature:) }

  let(:endpoint) { "http://example.com/nope" }
  let(:api_key) { "1234" }
  let(:embedding_model) { "embedding-3-large" }
  let(:model) { "test-gpt-35" }
  let(:api_version) { "2024-02-15-preview" }
  let(:temperature) { 0.1 }
  let(:openai) { instance_double(OpenAI::Client, chat: chat_response) }
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

  before do
    allow(OpenAI::Client).to receive(:new).and_return(openai)
  end

  describe "#embed" do
    let(:content) { "Any old content" }
    let(:result) { subject.embed(content) }

    it "returns an embedding", :skip do
      expect(result['embedding']).to be_a(Array)
    end
  end

  describe "#complete" do
    completion = nil
    let(:result) { completion } # lazy
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

    before do
      subject.complete(content) do |str|
        completion = str
      end
    end

    it "yields a string" do
      expect(result).to be_a(String)
    end

    it "identifies 'Einstein' within completion" do
      expect(result).to eq("Einstein")
    end

    it "calls the OpenAI client with the correct messages" do
      subject.complete(content)
      expect(openai).to have_received(:chat).with(expected_complete_params)
    end

    context "when it gets throttled by the server" do
      before do
        allow(openai).to receive(:chat).and_raise(Faraday::TooManyRequestsError)
        allow(Setting).to receive(:get).with("openai_client_retry_wait_time_s", anything).and_return(0)
        allow(Setting).to receive(:get).with("openai_client_retry_attempts", anything).and_return(1)
      end

      it "raises a RetryableError" do
        expect { subject.complete(content) }.to raise_error(LlmClients::RetryableError)
      end
    end
  end

  describe "#chat", :skip do
    response = nil
    let(:result) { response } # lazy
    let(:content) { 'Please explain why the sky is blue in a single sentence suitable for a child who is five years old.' }

    let(:conversation) { create(:conversation, messages: []) }

    before do
      msg = create(:message, content:, conversation:)
      response = ""
      subject.chat(msg) do |str|
        response << str
      end
    end

    it "yields a non-empty string" do
      expect(response.size).to be > 0
    end

    it "identifies 'scatter' in the answer" do
      expect(result).to include("scatter")
    end
  end
end
