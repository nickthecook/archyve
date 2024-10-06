RSpec.shared_examples "chunkers supporting overlap" do
  let(:document) { create(:documentx) }

  describe "#chunk" do
    context "with overlap" do
      it "returns chunks no bigger than 'chunk_size + chunk_overlap'" do
        parser = Parsers::CommonMark.new(document)
        chunks = subject.chunk(parser)
        expect(chunks.first.content.size).to be <= chunk_size + chunk_overlap
        expect(chunks.last.content.size).to be <= chunk_size + chunk_overlap
      end
    end

    context "without overlap" do
      let(:chunk_overlap) { 0 }

      it "returns chunks no bigger than 'chunk_size'" do
        parser = Parsers::CommonMark.new(document)
        chunks = subject.chunk(parser)
        expect(chunks.first.content.size).to be <= chunk_size
        expect(chunks.last.content.size).to be <= chunk_size
      end
    end
  end
end
