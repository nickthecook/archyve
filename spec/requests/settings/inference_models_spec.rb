require "rails_helper"

RSpec.describe "Settings::InferenceModels", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }
  let(:server) { create(:ollama_server) }

  before { sign_in(admin) }

  describe "POST /settings/inference_servers/:id/models" do
    subject(:request) do
      post settings_inference_server_models_path(server), params: { inference_model: attributes }
    end

    context "with a chat model" do
      let(:attributes) { { name: "llama3.1:8b", kind: "chat", context_window: "8192", supports_tools: "1" } }

      it "creates it" do
        expect { request }.to change(InferenceModel, :count).by(1)
      end

      it "records that it can call tools" do
        request
        expect(InferenceModel.last).to be_supports_tools
      end
    end

    context "with an embedding model whose dimensions don't fit the column" do
      let(:attributes) { { name: "mxbai-embed-large", kind: "embedding", dimensions: "1024" } }

      it "doesn't create it" do
        expect { request }.not_to change(InferenceModel, :count)
      end

      it "re-renders with the reason" do
        request
        expect(response.body).to include("vector(768)")
      end
    end

    context "with an embedding model while the corpus is already embedded" do
      let(:attributes) { { name: "nomic-embed-text:v1.5", kind: "embedding", dimensions: "768" } }

      before { create(:embedding, embedding_model: "mxbai-embed-large") }

      it "doesn't create it" do
        expect { request }.not_to change(InferenceModel, :count)
      end
    end
  end

  describe "PATCH /settings/inference_servers/:id/models/:id" do
    subject(:request) do
      patch settings_inference_server_model_path(server, model), params: { inference_model: attributes }
    end

    context "with a chat model" do
      let(:model) { create(:inference_model, inference_server: server) }
      let(:attributes) { { display_name: "Llama", kind: "embedding" } }

      it "applies the change" do
        request
        expect(model.reload.display_name).to eq("Llama")
      end

      # Kind is dropped on update: a chat model that became an embedder would
      # strand nothing, but the reverse would orphan every vector naming it.
      it "ignores an attempt to change its kind" do
        request
        expect(model.reload).to be_chat
      end
    end

    context "with the embedding model once the corpus is embedded" do
      let(:model) { create(:embedding_model, inference_server: server) }
      let(:attributes) { { name: "something-else" } }

      before do
        model
        create(:embedding, embedding_model: model.name)
      end

      # The show page hides this control. Both halves are needed — hiding a
      # link is not access control, and this is the half curl can't skip.
      it "is refused" do
        request
        expect(model.reload.name).to eq("nomic-embed-text:v1.5")
      end

      it "says why" do
        request
        expect(flash[:alert]).to include("re-embedding")
      end
    end
  end

  describe "DELETE /settings/inference_servers/:id/models/:id" do
    subject(:request) { delete settings_inference_server_model_path(server, model) }

    context "with a chat model" do
      let!(:model) { create(:inference_model, inference_server: server) }

      it "removes it" do
        expect { request }.to change(InferenceModel, :count).by(-1)
      end
    end

    context "with the embedding model while nothing is embedded" do
      let!(:model) { create(:embedding_model, inference_server: server) }

      # Nothing to strand, so this is just undoing a setup step.
      it "removes it" do
        expect { request }.to change(InferenceModel, :count).by(-1)
      end
    end

    context "with the embedding model once the corpus is embedded" do
      let!(:model) { create(:embedding_model, inference_server: server) }

      before { create(:embedding, embedding_model: model.name) }

      it "is refused" do
        expect { request }.not_to change(InferenceModel, :count)
      end

      it "says how much depends on it" do
        request
        follow_redirect!
        expect(response.body).to include("1 chunk is embedded with #{model.name}")
      end
    end
  end
end
