RSpec.describe Api::ModelLoader do
  subject { described_class.new(model:, traceable: ) }

  let(:model) { "llama3" }
  let(:traceable) { nil }

  let!(:model_config) { create(:model_config, name: "llama3") }
  let(:model_server) { create(:model_server) }

  before do
    model_server
  end

  describe "#new" do
    context "when no model given" do
      let(:model) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Api::ModelError, "No model given, and no default chat model configured.")
      end

      context "when the given model does not exist" do
        let(:model) { "mixalot:92b" }

        it "raises an error" do
          expect { subject }.to raise_error(Api::ModelError, "Given model 'mixalot:92b' not found.")
        end
      end
    end

    context "when no ModelServer is configured" do
      let(:model_server) { nil }

      it "raises an error" do
        expect { subject.model_config }.to raise_error(Api::ModelError, "No ModelServer configured. Please create one through the admin UI.")
      end
    end
  end

  describe "#model_config" do
    it "returns the ModelConfig with the given model string" do
      expect(subject.model_config).to eq(model_config)
    end

    context "when given model is model and not name" do
      let!(:model_config) { create(:model_config, model: "llama3") }

      it "returns the ModelConfig with the given name" do
        expect(subject.model_config).to eq(model_config)
      end
    end
  end

  describe "#client" do
    before do
      allow(LlmClients::Ollama::Client).to receive(:new).and_call_original
    end

    it "returns an instance of LlmClients::Client for the given provider" do
      expect(subject.client("ollama")).to be_a(LlmClients::Ollama::Client)
    end

    it "configures the client correctly" do
      subject.client("ollama")
      expect(LlmClients::Ollama::Client).to have_received(:new).with({
        endpoint: model_server.url,
        api_key: nil,
        model: model_config.model,
        traceable: nil,
      })
    end

    context "when given a traceable" do
      let(:traceable) { instance_double(Client) }

      it "passes the traceable to the client" do
        subject.client("ollama")
        expect(LlmClients::Ollama::Client).to have_received(:new).with({
          endpoint: model_server.url,
          api_key: nil,
          model: model_config.model,
          traceable:,
        })
      end
    end
  end
end
