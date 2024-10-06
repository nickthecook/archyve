RSpec.shared_examples "all chunkers" do
  let(:document) { create(:documentx) }

  describe "#chunk" do
    it "returns Enumerable" do
      parser = Parsers::CommonMark.new(document)
      chunks = subject.chunk(parser)
      expect(chunks).to be_a(Enumerable)
    end

    it "returns chunk records" do
      parser = Parsers::CommonMark.new(document)
      chunks = subject.chunk(parser)
      expect(chunks.first).to be_a(Chunkers::ChunkRecord)
      expect(chunks.last).to be_a(Chunkers::ChunkRecord)
    end
  end
end
