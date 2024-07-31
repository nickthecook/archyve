RSpec.describe Embedder do
  subject { described_class.new(model_config:, traceable:) }

  let(:traceable) { nil }

  let(:model_server) { create(:model_server, provider: "ollama", url: 'http://localhost:11434', active: false) }
  let(:model_config) { create(:model_config, name: "Nomic", model: "nomic-embed-text", model_server:, embedding: true) }

  describe "#new" do
    context "when no model config given" do
      let(:model_config) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(NameError)
      end
    end
  end

  describe "#embed" do
    context "when no ModelServer is configured" do
      let(:model_server) { nil }

      it "raises an error" do
        expect { subject.embed("Why is the sky blue") }.to raise_error(NameError)
      end
    end

    context "when ModelServer is available" do
      it "returns an embedding for 'Why is the sky blue?'" do
        expect(subject.embed("Why is the sky blue")).to be_a(Array)
      end
    end
  end
end
