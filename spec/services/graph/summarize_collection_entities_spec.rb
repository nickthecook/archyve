RSpec.describe Graph::SummarizeCollectionEntities do
  subject { described_class.new(collection, force_all:) }

  let(:collection) { create(:collection, state: :created, graph_entities:) }
  let(:force_all) { false }
  let(:graph_entities) { create_list(:graph_entity, 3) }
  let(:summarizer) { instance_double(Graph::EntitySummarizer, summarize: nil) }

  include_context "with default models"

  before do
    graph_entities[1].update!(summary: "Yep, it's an entity.", summary_outdated: false)
    allow(Graph::EntitySummarizer).to receive(:new) { summarizer }
  end

  describe "#execute" do
    it "sets the collection state" do
      expect { subject.execute }.to change { collection.reload.state }.from("created").to("summarized")
    end

    it "updates the process_step" do
      expect { subject.execute }.to change { collection.reload.process_step }.from(nil).to(2)
    end

    it "updates the process_steps" do
      expect { subject }.to change(collection, :process_steps).from(nil).to(2)
    end

    it "calls the summarizer for each entity" do
      subject.execute

      expect(summarizer).to have_received(:summarize).exactly(2).times
      expect(summarizer).to have_received(:summarize).with(graph_entities[0])
      expect(summarizer).to have_received(:summarize).with(graph_entities[2])
    end

    context "when force_all is true" do
      let(:force_all) { true }

      it "calls the summarizer for each entity" do
        subject.execute

        expect(summarizer).to have_received(:summarize).exactly(3).times
        expect(summarizer).to have_received(:summarize).with(graph_entities[0])
        expect(summarizer).to have_received(:summarize).with(graph_entities[1])
        expect(summarizer).to have_received(:summarize).with(graph_entities[2])
      end
    end
  end
end
