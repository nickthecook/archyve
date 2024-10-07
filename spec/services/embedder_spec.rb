RSpec.describe Embedder do
  subject { described_class.new(model_config:, traceable:) }

  let(:traceable) { nil }

  let(:model_server) { create(:model_server, provider: "ollama", url: 'http://localhost:11434', active: false) }
  let(:model_config) { create(:model_config, name: "Nomic", model: "nomic-embed-text", model_server:, embedding: true) }

  let(:client_helper) { instance_double(Helpers::ModelClientHelper, client: client)}
  let(:client) { instance_double(LlmClients::Ollama::Client, embed: embeddings) }
  let(:embeddings) { { "embedding" => [1.0, 1.1, 1.2] } }

  before do
    allow(Helpers::ModelClientHelper).to receive(:new).and_return(client_helper)
  end

  describe "#embed" do
    context "when ModelServer is available" do
      it "returns an embedding for 'Why is the sky blue?'" do
        expect(subject.embed("Why is the sky blue?")).to be_a(Array)
      end
    end
  end
end
