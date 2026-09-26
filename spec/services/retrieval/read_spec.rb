require "rails_helper"

RSpec.describe Retrieval::Read do
  describe "#call" do
    subject(:read) { described_class.new(corpus: Retrieval::Corpus.new(user:, scope:)) }

    let(:result) { read.call(document.id, from:, to:) }

    let(:user) { create(:user) }
    let(:scope) { nil }
    let(:from) { nil }
    let(:to) { nil }

    let(:collection) { create(:collection) }
    let(:document) { create(:document, title: "Handbook") }

    before do
      5.times { |position| create(:chunk, document:, position:, content: "Chunk #{position + 1}.") }
      create(:collection_membership, collection:, document:, origin: "manual")
      create(:collection_user, collection:, user:)
    end

    context "with a range inside the document" do
      let(:from) { 2 }
      let(:to) { 4 }

      it "returns exactly that run, in document order" do
        expect(result.hits.map { it.chunk.position }).to eq([1, 2, 3])
      end

      it "reports the range it returned" do
        expect([result.from, result.to]).to eq([2, 4])
      end

      it "reports how much document there is" do
        expect(result.total).to eq(5)
      end

      # Nothing ranked these chunks — the model asked for them by position —
      # so a distance would be a relevance reading nobody took.
      it "leaves them unranked" do
        expect(result.hits.map(&:distance)).to all(be_nil)
      end
    end

    context "with no range at all" do
      it "starts at the beginning" do
        expect(result.from).to eq(1)
      end

      it "returns the whole document when it fits in a page" do
        expect(result.to).to eq(5)
      end

      it "has nothing left over" do
        expect(result).not_to be_more
      end
    end

    context "when the document runs past a page" do
      before { 20.times { |n| create(:chunk, document:, position: 5 + n, content: "More #{n}.") } }

      it "stops at the page limit" do
        expect(result.to).to eq(described_class::MAX_CHUNKS)
      end

      it "says there is more to come, so the model can ask again" do
        expect(result).to be_more
      end
    end

    # Chunks vary in size, so the count is only half the guard — what actually
    # matters is how much of the model's context one call can fill.
    context "when the chunks are enormous" do
      let(:document) { create(:document, title: "Doorstop") }

      before do
        Chunk.where(document:).destroy_all
        3.times { |position| create(:chunk, document:, position:, content: "x" * 9_000) }
      end

      # Two fit in the budget and the third would overrun it, so it stops at
      # two — well short of the chunk limit.
      it "stops on the character budget rather than the chunk count" do
        expect(result.to).to eq(2)
      end
    end

    context "when a single chunk is larger than the whole budget" do
      let(:document) { create(:document, title: "Monolith") }

      before do
        Chunk.where(document:).destroy_all
        create(:chunk, document:, position: 0, content: "x" * 50_000)
      end

      # Coming back empty would read as "this document is blank", which is the
      # one answer that isn't true.
      it "returns it anyway" do
        expect(result.hits.size).to eq(1)
      end
    end

    context "when the range starts past the end" do
      let(:from) { 99 }

      it "refuses rather than returning the last chunk instead" do
        expect(result.refusal).to eq(:out_of_range)
      end

      it "says how long the document is, so the model can retry" do
        expect(result.total).to eq(5)
      end
    end

    context "when `to` is below `from`" do
      let(:from) { 3 }
      let(:to) { 1 }

      it "reads the one chunk it asked to start at rather than nothing" do
        expect([result.from, result.to]).to eq([3, 3])
      end
    end

    context "when the document has not been processed" do
      before { Chunk.where(document:).destroy_all }

      # Distinct from an empty read: text is coming, just not yet, and that is
      # a different thing to tell someone.
      it "says so rather than reporting it missing" do
        expect(result.refusal).to eq(:not_processed)
      end
    end

    context "when they hold no grant on its collection" do
      before { CollectionUser.where(user:).destroy_all }

      it "refuses" do
        expect(result.refusal).to eq(:not_found)
      end
    end

    context "when the chat is scoped to a different collection" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ c: [create(:collection).slug] }, user:) }

      it "refuses, even to an admin" do
        expect(result.refusal).to eq(:not_found)
      end
    end

    context "when no such document exists" do
      let(:result) { read.call(999_999) }

      it "refuses" do
        expect(result.refusal).to eq(:not_found)
      end
    end
  end
end
