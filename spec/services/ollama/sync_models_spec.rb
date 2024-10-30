RSpec.describe Ollama::SyncModels do
  subject { described_class.new(model_server) }

  let(:model_server) { create(:model_server, name:, url:, provider:) }
  let(:name) { "ChadGPT" }
  let(:url) { "http://localhost:11111" }
  let(:provider) { "ollama" }

  let(:fetch_models) { instance_double(Ollama::FetchModels, execute: model_set) }
  let(:model_set) do
    [
      LlmClients::Ollama::ModelDetails.new("llava:latest", "llava:latest", llava_details),
      LlmClients::Ollama::ModelDetails.new("llama3.1:latest", "llama3.1:latest", llama_details),
      LlmClients::Ollama::ModelDetails.new("nomic-embed-text:latest", "nomic-embed-text:latest", nomic_details),
    ]
  end
  let(:llava_details) { json_fixture("llm_clients/ollama/fetch_model_details_llava.json") }
  let(:llama_details) { json_fixture("llm_clients/ollama/fetch_model_details_llama.json") }
  let(:nomic_details) { json_fixture("llm_clients/ollama/fetch_model_details_nomic.json") }

  let(:client) { instance_double(LlmClients::Ollama::Client, list_models:) }
  let(:list_models) { json_fixture("llm_clients/ollama/list_models.json") }

  before do
    allow(Ollama::FetchModels).to receive(:new).and_return(fetch_models)
    allow(LlmClients::Ollama::Client).to receive(:new).and_return(client)
  end

  describe "#execute" do
    let(:result) { subject.execute }
    let(:model_configs) { ModelConfig.order(:id) }

    it "returns three ModelConfigs" do
      expect { result }.to change(ModelConfig, :count).from(0).to(3)
      expect(result).to all be_a(ModelConfig)
    end

    it "creates the correct ModelConfigs" do
      result

      expect(model_configs.first).to have_attributes(
        name: "llava:latest",
        model: "llava:latest",
        context_window_size: 2048,
        temperature: 0.8,
        embedding?: false,
        vision?: true
      )
      expect(model_configs.second).to have_attributes(
        name: "llama3.1:latest",
        model: "llama3.1:latest",
        context_window_size: 2048,
        temperature: 0.8,
        embedding?: false,
        vision?: false
      )
      expect(model_configs.third).to have_attributes(
        name: "nomic-embed-text:latest",
        model: "nomic-embed-text:latest",
        context_window_size: 8192,
        temperature: 0.8,
        embedding?: true,
        vision?: false
      )
    end
  end
end
