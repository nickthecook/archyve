require "rails_helper"

RSpec.describe InferenceModel do
  describe "validations" do
    it "requires a name" do
      expect(build(:inference_model, name: nil)).not_to be_valid
    end

    it "refuses two models with the same name on one server" do
      server = create(:ollama_server)
      create(:inference_model, inference_server: server, name: "llama3.1:8b")
      expect(build(:inference_model, inference_server: server, name: "llama3.1:8b")).not_to be_valid
    end

    it "allows the same name on a different server" do
      create(:inference_model, inference_server: create(:ollama_server), name: "llama3.1:8b")
      expect(build(:inference_model, inference_server: create(:ollama_server), name: "llama3.1:8b")).to be_valid
    end
  end

  describe "dimensions" do
    context "when the model is an embedder" do
      it "requires them" do
        expect(build(:embedding_model, dimensions: nil)).not_to be_valid
      end

      # The embeddings column is a vector(768) with one cosine HNSW index, so a
      # model of any other width physically cannot be stored in it.
      context "when they don't match the column" do
        subject(:model) { build(:embedding_model, dimensions: 1024) }

        it "is invalid" do
          expect(model).not_to be_valid
        end

        it "says why" do
          model.valid?
          expect(model.errors.full_messages.to_sentence).to include("vector(768)")
        end
      end
    end

    context "when the model is for chat" do
      it "doesn't require them" do
        expect(build(:inference_model, kind: :chat, dimensions: nil)).to be_valid
      end
    end
  end

  # The setting names a model; this resolves it. Anything that can't be the
  # answer — deleted, disabled, toolless — has to fall back rather than leave
  # chat with no model, which is why every case here ends in a model or nil.
  describe ".default_chat" do
    let!(:first) { create(:inference_model, :tools, name: "a-first") }
    let!(:other) { create(:inference_model, :tools, name: "z-other") }

    context "with nothing set" do
      it "falls back to the first usable chat model" do
        expect(described_class.default_chat).to eq(first)
      end
    end

    context "with a model set" do
      before { Setting["chat.default_model_id"] = other.id }

      it { expect(described_class.default_chat).to eq(other) }
    end

    context "with a model set that has since been deleted" do
      before do
        Setting["chat.default_model_id"] = other.id
        other.destroy!
      end

      it "falls back rather than leaving chat with nothing" do
        expect(described_class.default_chat).to eq(first)
      end
    end

    context "with a model set that has since been disabled" do
      before do
        Setting["chat.default_model_id"] = other.id
        other.update!(enabled: false)
      end

      it { expect(described_class.default_chat).to eq(first) }
    end

    context "with a model set that can't call tools" do
      before do
        Setting["chat.default_model_id"] = other.id
        other.update!(supports_tools: false)
      end

      it { expect(described_class.default_chat).to eq(first) }
    end

    context "with no usable chat model at all" do
      before { InferenceModel.delete_all }

      it { expect(described_class.default_chat).to be_nil }
    end
  end

  describe "only one embedding model" do
    before { create(:embedding_model) }

    it "refuses a second one" do
      expect(build(:embedding_model, inference_server: create(:ollama_server))).not_to be_valid
    end

    it "still allows chat models" do
      expect(build(:inference_model, kind: :chat)).to be_valid
    end
  end

  describe "the corpus freeze" do
    context "when nothing is embedded yet" do
      it "allows an embedding model to be created" do
        expect(build(:embedding_model)).to be_valid
      end
    end

    context "when the corpus holds vectors from another model" do
      before { create(:embedding, embedding_model: "mxbai-embed-large") }

      # Vectors from different models aren't comparable, so adopting a new one
      # strands everything already stored — search keeps running and keeps
      # returning nothing useful.
      it "refuses the new embedder" do
        expect(build(:embedding_model, name: "nomic-embed-text:v1.5")).not_to be_valid
      end

      it "names what would be stranded" do
        model = build(:embedding_model, name: "nomic-embed-text:v1.5")
        model.valid?
        expect(model.errors.full_messages.to_sentence).to include("mxbai-embed-large")
      end
    end

    context "when the corpus holds vectors from this same model" do
      before { create(:embedding, embedding_model: "nomic-embed-text:v1.5") }

      # Declaring the embedder the corpus is already full of is not a change.
      # It is what an install predating these rows does to describe itself, and
      # what the seeds do on an archive that has been embedding all along.
      it "allows it" do
        expect(build(:embedding_model, name: "nomic-embed-text:v1.5")).to be_valid
      end
    end
  end

  # The other half of the freeze: that one refuses a different embedder while
  # vectors exist, this refuses removing the one they came from.
  describe "removing a model the corpus depends on" do
    subject(:removal) { model.destroy }

    context "when it is the embedder the corpus was built with" do
      let!(:model) { create(:embedding_model, name: "nomic-embed-text:v1.5") }

      before { create_list(:embedding, 2, embedding_model: "nomic-embed-text:v1.5") }

      it "is refused" do
        expect { removal }.not_to change(described_class, :count)
      end

      it "says how much depends on it" do
        removal
        expect(model.errors.full_messages.to_sentence).to include("2 chunks are embedded")
      end
    end

    context "when nothing was embedded with it" do
      let!(:model) { create(:embedding_model) }

      it "is removed" do
        expect { removal }.to change(described_class, :count).by(-1)
      end
    end

    # A chat model leaves nothing behind that depends on it.
    context "when it is a chat model and the corpus is full" do
      let!(:model) { create(:inference_model, kind: :chat) }

      before { create(:embedding, embedding_model: "nomic-embed-text:v1.5") }

      it "is removed" do
        expect { removal }.to change(described_class, :count).by(-1)
      end
    end
  end

  describe ".active_embedding" do
    context "when nothing is configured" do
      # A fresh install seeds no server at all, so nil is an ordinary answer
      # rather than an error — callers decide what to say about it.
      it "is nil" do
        expect(described_class.active_embedding).to be_nil
      end
    end

    context "when an embedding model exists" do
      let!(:model) { create(:embedding_model) }

      it "returns it" do
        expect(described_class.active_embedding).to eq(model)
      end
    end

    context "when the embedding model is disabled" do
      before { create(:embedding_model, enabled: false) }

      it "is nil" do
        expect(described_class.active_embedding).to be_nil
      end
    end
  end
end
