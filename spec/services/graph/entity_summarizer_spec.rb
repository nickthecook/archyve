RSpec.describe Graph::EntitySummarizer do
  subject { described_class.new(model_config, traceable:) }

  let(:traceable) { nil }
  let(:llm_client) { instance_double(LlmClients::Ollama::Client, complete: completion) }
  let(:completion) { "Welp, looks like you gotcherself an entity there." }
  let(:entity) { instance_double(GraphEntity, update!: nil, name: "Entity Zero", descriptions: []) }

  include_context "with default models"

  before do
    allow(LlmClients::Ollama::Client).to receive(:new) { llm_client }
  end

  describe "#summarize" do
    it "sets the entity summary" do
      subject.summarize(entity)
      expect(entity).to have_received(:update!).with(summary: completion, summary_outdated: false)
    end
  end
end
