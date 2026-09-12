require "rails_helper"

RSpec.describe Retrieval::Fuse do
  describe ".call" do
    subject(:result) { described_class.call(ranked_lists, limit:) }

    let(:limit) { 10 }

    # Stand-ins for the Embedding rows a nearest-neighbor query returns: fusion
    # only ever reads the chunk id and the distance, and building real vectors
    # would test pgvector rather than the ranking. A plain double, not an
    # instance_double — `neighbor_distance` is attached to the result set by the
    # neighbor gem, so it isn't on the class to verify against.
    def candidate(chunk_id, distance)
      chunk = instance_double(Chunk, id: chunk_id, document: instance_double(Document))
      double("Embedding", chunk_id:, neighbor_distance: distance, chunk:)
    end

    context "with one query" do
      let(:ranked_lists) { [[candidate(1, 0.10), candidate(2, 0.20), candidate(3, 0.30)]] }

      it "keeps the order the query returned" do
        expect(result.map(&:handle)).to eq([1, 2, 3])
      end

      it "reports each chunk's own distance" do
        expect(result.map(&:distance)).to eq([0.10, 0.20, 0.30])
      end
    end

    context "when two queries agree on a chunk that neither ranked first" do
      let(:ranked_lists) do
        [
          [candidate(1, 0.10), candidate(9, 0.15)],
          [candidate(2, 0.11), candidate(9, 0.16)]
        ]
      end

      # The point of fusion: agreement across queries outweighs winning one of
      # them. Sorting the merged pile by distance would put chunk 1 on top.
      it "ranks the agreed chunk above either query's winner" do
        expect(result.first.chunk.id).to eq(9)
      end
    end

    context "when one query's distances are uniformly better than another's" do
      let(:ranked_lists) do
        [
          [candidate(1, 0.05), candidate(2, 0.06), candidate(3, 0.07)],
          [candidate(4, 0.40), candidate(5, 0.41), candidate(6, 0.42)]
        ]
      end

      # A query landing near the middle of the corpus scores better against
      # everything. Raw-distance sorting would hand it every slot.
      it "gives the worse-scoring query its share of the top slots" do
        expect(result.first(2).map { it.chunk.id }).to contain_exactly(1, 4)
      end
    end

    context "when the same chunk comes back at different distances" do
      let(:ranked_lists) { [[candidate(1, 0.30)], [candidate(1, 0.10)]] }

      it "returns it once" do
        expect(result.size).to eq(1)
      end

      it "keeps the best distance any query achieved" do
        expect(result.first.distance).to eq(0.10)
      end
    end

    context "when more chunks survive than the limit allows" do
      let(:limit) { 2 }
      let(:ranked_lists) { [[candidate(1, 0.10), candidate(2, 0.20), candidate(3, 0.30)]] }

      it "returns only the limit" do
        expect(result.size).to eq(2)
      end

      it "numbers the handles from one, in final order" do
        expect(result.map(&:handle)).to eq([1, 2])
      end
    end

    context "with no queries at all" do
      let(:ranked_lists) { [] }

      it "returns nothing" do
        expect(result).to be_empty
      end
    end
  end
end
