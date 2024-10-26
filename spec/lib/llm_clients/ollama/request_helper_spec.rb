RSpec.describe LlmClients::Ollama::RequestHelper do
  subject { described_class.new(endpoint, api_key, embedding_model, model, temperature) }

  let(:endpoint) { 'http://localhost/v1' }
  let(:api_key) { 'fake-api-key' }
  let(:embedding_model) { 'nomic-embed-text' }
  let(:model) { 'gemma2:8b' }
  let(:temperature) { 0.1 }
  let(:content) { 'This is a test' }

  describe "#embed_request" do
    let(:result) { subject.embed_request(content) }

    it "returns an embed request_object" do
      expect(result).to be_a(Net::HTTP::Post)
    end

    it "sets the correct headers" do
      expect(result['Content-Type']).to eq('application/json')
      expect(result['Authorization']).to eq("Bearer fake-api-key")
    end

    it "sets the correct uri" do
      expect(result.uri.to_s).to eq('http://localhost/v1/api/embeddings')
    end

    it "generates the correct body" do
      expect(result.body).to eq({ model: "nomic-embed-text", prompt: "This is a test" }.to_json)
    end
  end

  describe "#completion_request" do
    let(:result) { subject.completion_request(content) }

    it "returns a completion request_object" do
      expect(result).to be_a(Net::HTTP::Post)
    end

    it "sets the correct headers" do
      expect(result['Content-Type']).to eq('application/json')
      expect(result['Authorization']).to eq("Bearer fake-api-key")
    end

    it "sets the correct uri" do
      expect(result.uri.to_s).to eq('http://localhost/v1/api/generate')
    end

    it "generates the correct body" do
      expect(result.body).to eq(
        {
          model: "gemma2:8b",
          prompt: "This is a test",
          temperature: 0.1,
          stream: true,
          max_tokens: 200,
        }.to_json
      )
    end
  end

  describe "#chat_request" do
    let(:result) { subject.chat_request(messages) }

    let(:messages) do
      [
        { role: "user", content: "write a simple ruby program" },
        { role: "assistant", content: "`rm -rf /`" },
        { role: "user", content: "not exactly what I had in mind..." },
      ]
    end

    it "returns a chat request_object" do
      expect(result).to be_a(Net::HTTP::Post)
    end

    it "sets the correct headers" do
      expect(result['Content-Type']).to eq('application/json')
      expect(result['Authorization']).to eq("Bearer fake-api-key")
    end

    it "sets the correct uri" do
      expect(result.uri.to_s).to eq('http://localhost/v1/api/chat')
    end

    it "generates the correct body" do
      expect(result.body).to eq({ model: "gemma2:8b", messages: }.to_json)
    end
  end

  describe "#image_request" do
    let(:model) { 'llava' }
    let(:content) { 'Describe this image' }

    let(:images) { [Base64.strict_encode64(file_fixture('images/hut_in_forest.jpg').read)] }
    let(:result) { subject.image_request(content, images:) }

    it "returns a completion request_object" do
      expect(result).to be_a(Net::HTTP::Post)
    end

    it "sets the correct headers" do
      expect(result['Content-Type']).to eq('application/json')
      expect(result['Authorization']).to eq("Bearer fake-api-key")
    end

    it "sets the correct uri" do
      expect(result.uri.to_s).to eq('http://localhost/v1/api/generate')
    end

    it "generates the correct body" do
      expect(result.body).to eq(
        {
          model: "llava",
          prompt: "Describe this image",
          images: [Base64.strict_encode64(file_fixture('images/hut_in_forest.jpg').read)],
          temperature: 0.1,
          stream: true,
          max_tokens: 200,
        }.to_json
      )
    end
  end
end
