require "rails_helper"

# A fixed-set agent's corpus has no user filter, so a bug here shows one person
# another's documents. These run through the real Search, Read and List rather
# than only the corpus's own methods.
RSpec.describe Retrieval::FixedCorpus do
  subject(:corpus) { described_class.new(agent) }

  let!(:embedding_model) { create(:embedding_model) }

  let(:agent) { create(:agent, collection_mode: "fixed") }
  let(:shared) { create(:collection, name: "Shared handbook") }
  let(:private_collection) { create(:collection, name: "Board minutes") }
  let(:in_set) { create(:document, title: "Handbook") }
  let(:outside) { create(:document, title: "Minutes") }

  before do
    create(:collection_membership, collection: shared, document: in_set, origin: "manual")
    create(:collection_membership, collection: private_collection, document: outside, origin: "manual")
    [in_set, outside].each { create(:embedding, chunk: create(:chunk, document: it, position: 0)) }
    create(:agent_collection, agent:, collection: shared)
    allow(Embeddings::Embed).to receive(:query).and_return(Array.new(768) { 0.1 })
  end

  describe "searching" do
    let(:result) { Retrieval::Search.new(corpus:).call("anything") }

    it "finds documents in the agent's collections" do
      expect(result.hits.map { it.document.title }).to eq(["Handbook"])
    end

    context "when the agent has no collections" do
      before { agent.agent_collections.destroy_all }

      it "finds nothing, rather than everything" do
        expect(result.hits).to be_empty
      end
    end

    context "when a document has been removed from the collection" do
      before { CollectionMembership.find_by(document: in_set).update!(removed_at: Time.current) }

      it "no longer finds it" do
        expect(result.hits).to be_empty
      end
    end
  end

  describe "reading" do
    let(:read) { Retrieval::Read.new(corpus:) }

    it "reads a document in the agent's collections" do
      expect(read.call(in_set.id).document).to eq(in_set)
    end

    it "refuses one outside them" do
      expect(read.call(outside.id).document).to be_nil
    end
  end

  describe "listing" do
    let(:listing) { Retrieval::List.new(corpus:).collections }

    it "names only the agent's collections" do
      expect(listing.entries.map { it["name"] }).to eq(["Shared handbook"])
    end
  end

  describe "#label" do
    it "names the collections" do
      expect(corpus.label).to eq("Shared handbook")
    end

    context "when the agent has no collections" do
      before { agent.agent_collections.destroy_all }

      it { expect(corpus.label).to eq("no collections") }
    end
  end
end

RSpec.describe Retrieval::Corpus do
  describe ".for" do
    subject(:corpus) { described_class.for(conversation) }

    let(:conversation) { create(:conversation, agent:) }

    context "with an agent that draws on what the user can read" do
      let(:agent) { create(:agent) }

      it { is_expected.to be_a(described_class) }
    end

    context "with a fixed-set agent" do
      let(:agent) { create(:agent, collection_mode: "fixed") }

      it { is_expected.to be_a(Retrieval::FixedCorpus) }
    end
  end
end
