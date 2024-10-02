require 'rails_helper'

RSpec.describe ModelConfig do
  subject { create(:model_config, name: model_name, model:, model_server:, embedding:, context_window_size:) }

  let(:model_server) { create(:model_server, provider: "ollama", url: 'http://localhost:11434', active: false) }
  let(:model_name) { "Nomic" }
  let(:model) { "nomic-embed-text" }
  let(:embedding) { true }
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
end
