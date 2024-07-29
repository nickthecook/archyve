RSpec.describe Helpers::ModelClientHelper do
  subject { described_class.new(model_config:, traceable:) }

  let(:traceable) { nil }

  let(:model_server) { create(:model_server, provider: "ollama", url: 'http://localhost:11434', active: false) }
  let(:model_config) { create(:model_config, name: "Meta Llama3", model: "llama3", model_server:) }

  describe "#new" do
    context "when no model config given" do
      let(:model_config) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(NameError)
      end
    end
  end

  describe "#endpoint" do
    context "when no ModelServer is configured" do
      let(:model_server) { nil }

      it "raises an error" do
        expect { subject.endpoint }.to raise_error(NameError)
      end
    end

    context "when ModelServer is available" do
      it "returns server URL" do
        expect(subject.endpoint).to eq(model_server.url)
      end
    end
  end

  describe "#server_name" do
    context "when no ModelServer is configured" do
      let(:model_server) { nil }

      it "raises an error" do
        expect { subject.server_name }.to raise_error(NameError)
      end
    end

    context "when ModelServer is available" do
      it "returns server name" do
        expect(subject.server_name).to eq(model_server.name)
      end
    end
  end

  describe "#provider" do
    context "when no ModelServer is configured" do
      let(:model_server) { nil }

      it "raises an error" do
        expect { subject.provider }.to raise_error(NameError)
      end
    end

    context "when ModelServer is available" do
      it "returns server provider" do
        expect(subject.provider).to eq(model_server.provider)
      end
    end
  end

  describe "#model" do
    context "when given model_config" do
      it "returns the model name" do
        expect(subject.model).to eq("llama3")
      end
    end
  end

  describe "#embedding_model?" do
    context "when given a language model" do
      it "returns false" do
        expect(subject.embedding_model?).to be false
      end
    end

    context "when given an embedding model" do
      let(:model_config) { create(:model_config, name: "Nomic", model: "nomic-embed-text", model_server:, embedding: true) }

      it "returns true" do
        expect(subject.embedding_model?).to be true
      end
    end
  end

  describe "#client" do
    before do
      allow(LlmClients::Client).to receive(:client_class_for).and_call_original
      allow(LlmClients::Ollama::Client).to receive(:new).and_call_original
    end

    it "returns an instance of LlmClients::Client for the given provider" do
      expect(subject.client).to be_a(LlmClients::Ollama::Client)
    end

    context "when given a language model" do
      it "configures the client correctly" do
        subject.client
        expect(LlmClients::Ollama::Client).to have_received(:new).with({
          endpoint: model_server.url,
          api_key: model_server.api_key,
          model: model_config.model,
          batch_size: described_class::BATCH_SIZE,
          api_version: nil,
          embedding_model: nil,
          traceable: nil,
        })
      end
    end

    context "when given an embedding model" do
      let(:model_config) { create(:model_config, name: "Nomic", model: "nomic-embed-text", model_server:, embedding: true) }

      it "configures the client correctly" do
        subject.client
        expect(LlmClients::Ollama::Client).to have_received(:new).with({
          endpoint: model_server.url,
          api_key: model_server.api_key,
          embedding_model: model_config.model,
          model: nil,
          batch_size: described_class::BATCH_SIZE,
          api_version: nil,
          traceable: nil,
        })
      end
    end

    context "when given a traceable" do
      let(:traceable) { "Hello" }

      it "passes the traceable to the client" do
        subject.client
        expect(LlmClients::Ollama::Client).to have_received(:new).with({
          endpoint: model_server.url,
          api_key: model_server.api_key,
          model: model_config.model,
          batch_size: described_class::BATCH_SIZE,
          api_version: nil,
          embedding_model: nil,
          traceable:,
        })
      end
    end
  end
end
