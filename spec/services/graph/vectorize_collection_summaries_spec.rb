RSpec.describe Graph::VectorizeCollectionSummaries do
  subject { described_class.new(collection) }

  let(:collection) { create(:collection, graph_entities:) }
  let(:graph_entities) { entity_summaries.map { |summary| create(:graph_entity, summary:) } }
  let(:entity_summaries) { %w[one two three] }
  let(:embedder) { instance_double(Embedder, embed: [[1.0, 2.0, 3.0]]) }
  let(:chromadb) do
    instance_double(
      Chromadb::Client,
      create_collection: { "id" => "123" },
      collection_id: "123",
      add_entity_summary: "234"
    )
  end

  include_context "with default models"

  before do
    allow(Chromadb::Client).to receive(:new) { chromadb }
    allow(Embedder).to receive(:new) { embedder }
  end

  describe "#execute" do
    it "sets the collection state" do
      expect { subject.execute }.to change { collection.reload.state }.from("created").to("vectorized")
    end

    it "sets the process step" do
      expect { subject.execute }.to change(collection, :process_step).from(nil).to(3)
    end

    it "sets the process steps" do
      expect { subject.execute }.to change(collection, :process_steps).from(nil).to(3)
    end

    it "adds entity summaries to the vector DB" do
      subject.execute

      expect(chromadb).to have_received(:add_entity_summary).exactly(3).times
      expect(chromadb).to have_received(:add_entity_summary).with("123", "one", [[1.0, 2.0, 3.0]])
      expect(chromadb).to have_received(:add_entity_summary).with("123", "two", [[1.0, 2.0, 3.0]])
      expect(chromadb).to have_received(:add_entity_summary).with("123", "three", [[1.0, 2.0, 3.0]])
    end

    it "uses the collection as the traceable for the ChromaDB client" do
      subject.execute
      expect(Chromadb::Client).to have_received(:new).with(traceable: collection)
    end

    it "uses each entity as the traceable for the Embedder calls" do
      subject.execute
      expect(embedder).to have_received(:embed).with(entity_summaries[0], traceable: graph_entities[0])
      expect(embedder).to have_received(:embed).with(entity_summaries[1], traceable: graph_entities[1])
      expect(embedder).to have_received(:embed).with(entity_summaries[2], traceable: graph_entities[2])
    end
  end
end
