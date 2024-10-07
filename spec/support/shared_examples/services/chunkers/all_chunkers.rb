RSpec.shared_examples "all chunkers" do
  let(:document) { create(:documentx) }
  let(:parser) { Parsers::CommonMark.new(document) }
  let(:chunks) { subject.chunk(parser) }

  describe "#chunk" do
    it "returns Enumerable" do
      expect(chunks).to be_a(Enumerable)
    end

    it "returns chunk records" do
      expect(chunks.first).to be_a(Chunkers::ChunkRecord)
      expect(chunks.last).to be_a(Chunkers::ChunkRecord)
    end
  end
end
