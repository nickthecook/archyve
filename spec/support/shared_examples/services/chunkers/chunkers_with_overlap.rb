RSpec.shared_examples "chunkers supporting overlap" do
  let(:document) { create(:document, :with_file) }
  let(:parser) { Parsers::CommonMark.new(document) }
  let(:chunks) { subject.chunk(parser) }

  describe "#chunk" do
    context "with overlap" do
      it "returns chunks no bigger than 'chunk_size + chunk_overlap'" do
        expect(chunks.first.surrounding_content.size).to be <= chunk_size + chunk_overlap
        expect(chunks.last.surrounding_content.size).to be <= chunk_size + chunk_overlap
      end
    end

    context "without overlap" do
      let(:chunk_overlap) { 0 }

      it "returns chunks no bigger than 'chunk_size'" do
        expect(chunks.first.surrounding_content.size).to be <= chunk_size
        expect(chunks.last.surrounding_content.size).to be <= chunk_size
      end
    end
  end
end
