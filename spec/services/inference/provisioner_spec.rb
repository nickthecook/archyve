require "rails_helper"

RSpec.describe Inference::Provisioner do
  subject(:provisioner) { described_class.new(env) }

  let(:env) { { "ARCHYVE_INFERENCE" => servers.to_json } }
  let(:models) { [{ name: "qwen3:32b" }] }
  let(:servers) { [{ name: "GPU", type: "ollama", base_url: "http://gpu:11434", models: }] }

  def provisioned_server = InferenceServer.find_by(name: "GPU")
  def provisioned_model = provisioned_server.inference_models.find_by(name: "qwen3:32b")

  describe "#call" do
    let(:result) { provisioner.call }
    let(:errors) { result.select { it.level == :error }.map(&:message) }

    context "with a new server" do
      before { result }

      it "creates it as provisioned" do
        expect(provisioned_server).to have_attributes(provisioned: true, enabled: true, base_url: "http://gpu:11434")
      end

      it "creates its model as a tool-capable chat model" do
        expect(provisioned_model).to have_attributes(provisioned: true, kind: "chat", supports_tools: true)
      end
    end

    context "with an embedding model" do
      let(:models) { [{ name: "nomic-embed-text:v1.5", kind: "embedding", dimensions: 768 }] }

      it "creates it" do
        result
        expect(InferenceModel.active_embedding.name).to eq("nomic-embed-text:v1.5")
      end
    end

    context "with a key referenced from another variable" do
      let(:servers) { [{ name: "GPU", type: "openai", api_key_env: "GPU_KEY", models: }] }
      let(:env) { super().merge("GPU_KEY" => "sk-secret") }

      it "stores the key" do
        result
        expect(provisioned_server.api_key).to eq("sk-secret")
      end
    end

    context "with a key variable that isn't set" do
      let(:servers) { [{ name: "GPU", type: "openai", api_key_env: "GPU_KEY", models: }] }

      it "skips the server" do
        result
        expect(provisioned_server).to be_nil
      end

      it "says why" do
        expect(errors).to include(a_string_matching(/GPU_KEY, which isn't set/))
      end
    end

    context "with an unrecognised key" do
      let(:models) { [{ name: "qwen3:32b", context_window: 8192 }] }

      it "skips the model" do
        result
        expect(provisioned_server.inference_models).to be_empty
      end
    end

    context "with a chat model that can't call tools" do
      let(:models) { [{ name: "qwen3:32b", supports_tools: false }] }

      it "skips it" do
        result
        expect(provisioned_server.inference_models).to be_empty
      end
    end

    context "when the server was provisioned with a different address" do
      before do
        create(:ollama_server, name: "GPU", base_url: "http://old:11434", provisioned: true)
        result
      end

      it "updates it" do
        expect(provisioned_server.base_url).to eq("http://gpu:11434")
      end
    end

    context "when the server was retired earlier" do
      before do
        server = create(:ollama_server, name: "GPU", provisioned: true, enabled: false)
        create(:inference_model, :tools, inference_server: server, name: "qwen3:32b", provisioned: true, enabled: false)
        result
      end

      it "re-enables the server" do
        expect(provisioned_server).to be_enabled
      end

      it "re-enables the model" do
        expect(provisioned_model).to be_enabled
      end
    end

    context "when a provisioned model is no longer declared" do
      let!(:stale) do
        create(:inference_model, :tools, name: "old:7b", provisioned: true,
          inference_server: create(:ollama_server, name: "GPU", provisioned: true))
      end

      it "disables it rather than deleting it" do
        result
        expect(stale.reload).not_to be_enabled
      end
    end

    context "when a provisioned server is no longer declared" do
      let(:servers) { [] }
      let!(:stale) { create(:ollama_server, name: "Gone", provisioned: true) }
      let!(:model) { create(:inference_model, :tools, inference_server: stale, provisioned: true) }

      before { result }

      it "disables the server" do
        expect(stale.reload).not_to be_enabled
      end

      it "disables its models" do
        expect(model.reload).not_to be_enabled
      end
    end

    context "when the retired server holds the archive's embedder" do
      let(:servers) { [] }
      let!(:stale) { create(:ollama_server, name: "Gone", provisioned: true) }
      let!(:embedder) { create(:embedding_model, inference_server: stale, provisioned: true) }

      before do
        create(:embedding, embedding_model: embedder.name)
        result
      end

      it "keeps the embedder enabled" do
        expect(embedder.reload).to be_enabled
      end

      it "keeps the server enabled" do
        expect(stale.reload).to be_enabled
      end

      it "says why" do
        expect(errors).to include(a_string_matching(/archive is embedded with it/))
      end
    end

    context "when the variable is unset" do
      let(:env) { {} }
      let!(:stale) { create(:ollama_server, name: "Gone", provisioned: true) }

      it "retires everything provisioned" do
        result
        expect(stale.reload).not_to be_enabled
      end
    end

    context "when the variable isn't valid JSON" do
      let(:env) { { "ARCHYVE_INFERENCE" => "[{" } }
      let!(:stale) { create(:ollama_server, name: "Gone", provisioned: true) }

      it "leaves provisioned servers alone" do
        result
        expect(stale.reload).to be_enabled
      end
    end

    context "when an entry is malformed" do
      let(:servers) { [{ name: "Gone", type: "olama" }] }
      let!(:stale) { create(:ollama_server, name: "Gone", provisioned: true) }

      it "doesn't retire the server it names" do
        result
        expect(stale.reload).to be_enabled
      end
    end

    context "when a server added in Settings has the same name" do
      let!(:existing) { create(:ollama_server, name: "GPU", base_url: "http://mine:11434") }

      it "leaves it alone" do
        result
        expect(existing.reload).to have_attributes(provisioned: false, base_url: "http://mine:11434")
      end

      it "says why" do
        expect(errors).to include(a_string_matching(/conflicts with a server added in Settings/))
      end
    end

    context "when another embedding model exists" do
      let(:models) { [{ name: "mxbai-embed-large", kind: "embedding", dimensions: 768 }] }

      before { create(:embedding_model) }

      it "skips the model" do
        result
        expect(provisioned_server.inference_models).to be_empty
      end

      it "says why" do
        expect(errors).to include(a_string_matching(%r{GPU/mxbai-embed-large wasn't provisioned}))
      end
    end

    context "with a default chat model that isn't declared" do
      let(:env) { super().merge("ARCHYVE_DEFAULT_CHAT_MODEL" => "GPU/missing") }

      it "says so" do
        expect(errors).to include(a_string_matching(/names GPU\/missing/))
      end
    end
  end
end
