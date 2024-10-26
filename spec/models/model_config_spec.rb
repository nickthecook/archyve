require 'rails_helper'

RSpec.describe ModelConfig do
  subject { create(:model_config, name: model_name, model:, model_server:, embedding:, vision:, context_window_size:) }

  let(:model_server) { create(:model_server, provider: "ollama", url: 'http://localhost:11434', active: false) }
  let(:model_name) { "Nomic" }
  let(:model) { "nomic-embed-text" }
  let(:embedding) { true }
  let(:vision) { false }
  let(:context_window_size) { nil }

  describe "#context_window_size" do
    context "when nil in model config" do
      it "returns default from model server" do
        expect(subject.context_window_size).to eq(model_server.default_context_window_size)
      end
    end

    context "when set in model config" do
      let(:context_window_size) { 12345 }

      it "returns correct value" do
        expect(subject.context_window_size).to eq(12345)
      end
    end
  end

  describe "embedding model" do
    it "configured" do
      expect(subject.embedding?).to be true
    end

    it "cannot be set as default vision model" do
      expect { subject.make_active_vision_model }.to raise_error(ModelConfig::ModelTypeError)
    end

    context "when activated" do
      before do
        subject.make_active_embedding_model
      end

      it "succeeds" do
        expect(Setting.embedding_model).to eq(subject)
      end
    end
  end

  describe "vision model" do
    let(:vision) { true }
    let(:embedding) { false }
    let(:model_name) { "Llava" }
    let(:model) { "llava" }

    it "configured" do
      expect(subject.vision?).to be true
    end

    context "with embedding flag" do
      let(:embedding) { true }

      it "cannot be configured" do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "when activated" do
      before do
        subject.make_active_vision_model
      end

      it "succeeds" do
        expect(Setting.vision_model).to eq(subject)
      end
    end

    context "without activation" do
      it "succeeds" do
        expect(Setting.vision_model).to be_nil
      end
    end
  end
end
