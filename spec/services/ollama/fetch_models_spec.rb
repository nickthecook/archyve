RSpec.describe Ollama::FetchModels do
  subject { described_class.new(model_server) }

  let(:model_server) { create(:model_server, name:, url:, provider:) }
  let(:name) { "ChadGPT" }
  let(:url) { "http://example.com:11111" }
  let(:provider) { "ollama" }

  let(:client) { instance_double(LlmClients::Ollama::Client, list_models:) }
  let(:list_models) { json_fixture("llm_clients/ollama/list_models.json") }

  before do
    allow(LlmClients::Ollama::Client).to receive(:new).and_return(client)

    allow(client).to receive(:fetch_model_details).with("llava:latest").and_return(
      json_fixture("llm_clients/ollama/fetch_model_details_llava.json")
    )
    allow(client).to receive(:fetch_model_details).with("llama3.1:latest").and_return(
      json_fixture("llm_clients/ollama/fetch_model_details_llama.json")
    )
    allow(client).to receive(:fetch_model_details).with("nomic-embed-text:latest").and_return(
      json_fixture("llm_clients/ollama/fetch_model_details_nomic.json")
    )
  end

  describe "#execute" do
    let(:result) { subject.execute }

    it "returns a list of models in the server" do
      expect(result.size).to eq(3)
      expect(result).to all(be_an(LlmClients::Ollama::ModelDetails))
    end

    it "returns the correct model details" do
      expect(result).to contain_exactly(
        have_attributes(
          name: "llava:latest",
          context_window_size: 2048,
          temperature: 0.8,
          embedding?: false,
          vision?: true
        ),
        have_attributes(
          name: "llama3.1:latest",
          context_window_size: 2048,
          temperature: 0.8,
          embedding?: false,
          vision?: false
        ),
        have_attributes(
          name: "nomic-embed-text:latest",
          context_window_size: 8192,
          temperature: 0.8,
          embedding?: true,
          vision?: false
        )
      )
    end
  end
end
