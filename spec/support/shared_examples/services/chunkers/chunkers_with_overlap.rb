RSpec.shared_examples "chunkers supporting overlap" do
  # Requires
  # - `subject` to be instance of a chunker
  # - the following `let` variables to be defined
  #   - :text
  #   - :text_type
  #   - :chunk_size
  #   - :chunk_overlap

  describe "#chunk" do
    let(:chunks) { subject.chunk(text, text_type) }

    context "with overlap" do
      it "returns chunks no bigger than 'chunk_size + chunk_overlap'" do
        expect(chunks.first.content.size).to be <= chunk_size + chunk_overlap
        expect(chunks.last.content.size).to be <= chunk_size + chunk_overlap
      end
    end

    context "without overlap" do
      let(:chunk_overlap) { 0 }

      it "returns chunks no bigger than 'chunk_size'" do
        expect(chunks.first.content.size).to be <= chunk_size
        expect(chunks.last.content.size).to be <= chunk_size
      end
    end
  end
end
