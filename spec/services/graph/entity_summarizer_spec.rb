RSpec.describe Graph::EntitySummarizer do
  subject { described_class.new(model_config, traceable:) }

  let(:traceable) { nil }
  let(:completion) { "Welp, looks like you gotcherself an entity there." }
  let(:entity) { instance_double(GraphEntity, update!: nil, name: "Entity Zero", descriptions: []) }

  include_context "with default models"

  before do
    allow(llm_client).to receive(:complete).and_return(completion)
  end

  describe "#summarize" do
    it "sets the entity summary" do
      subject.summarize(entity)
      expect(entity).to have_received(:update!).with(summary: completion, summary_outdated: false)
    end

    context "when traceable is set" do
      let(:traceable) { "traceable!" }

      it "passes traceable to the LLM client" do
        subject.summarize(entity)
        expect(LlmClients::Ollama::Client).to have_received(:new).with(hash_including(traceable:))
      end
    end
  end
end
