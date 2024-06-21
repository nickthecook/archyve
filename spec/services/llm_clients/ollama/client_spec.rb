RSpec.describe LlmClients::Ollama::Client do
  subject do
    described_class.new(
      endpoint:,
      api_key:,
      model: nil,
      embedding_model: nil,
      temperature:,
      batch_size:
    )
  end

  let(:endpoint) { "http://localhost:11434/v1/completion" }
  let(:api_key) { "test-api-key" }
  let(:model) { "codestral:latest" }
  let(:embedding_model) { "nomic-embed-text" }
  let(:temperature) { 0.1 }
  let(:batch_size) { 10 }

  describe "#embed" do
    let(:result) { subject.embed(prompt) }
    let(:prompt) { "'Tis better to have loved and lost, my lads" }
    let(:response) do
      OpenStruct.new(
        parsed_response: JSON.parse(File.read("spec/fixtures/llm_clients/ollama/embedding_result.json")),
        success?: true
      )
    end
    let(:success) { true }
    let(:error) { nil }

    before do
      allow(HTTParty).to receive(:post).and_return(response)
    end

    it "raises no errors" do
      expect { result }.not_to raise_error
    end

    it "returns the parsed response" do
      expect(result).to eq(response.parsed_response)
    end

    context "when the request fails" do
      let(:response) do
        OpenStruct.new(
          success?: false,
          body: { "error" => "I'm a teapot" }.to_json,
          code: 418,
          message: "Welp, that didn't work",
          uri: "http://shard:11434/api/embed"
        )
      end

      it "raises ResponseError" do
        expect { result }.to raise_error(
          LlmClients::ResponseError,
          /Server responded with 418: Welp, that didn't work: http:\/\/shard:11434\/api\/embed; I'm a teapot/
        )
      end
    end
  end
end
