RSpec.shared_examples "all chunkers" do
  # Requires
  # - `subject` to be instance of a chunker
  # - the following `let` variables to be defined
  #   - :text
  #   - :text_type

  describe "#chunk" do
    let(:chunks) { subject.chunk(text, text_type) }

    it "returns Enumerable" do
      expect(chunks).to be_a(Enumerable)
    end

    it "returns chunk records" do
      expect(chunks.first).to be_a(Chunkers::ChunkRecord)
      expect(chunks.last).to be_a(Chunkers::ChunkRecord)
    end
  end
end
