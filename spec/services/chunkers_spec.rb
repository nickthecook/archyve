RSpec.describe Chunkers do
  subject { described_class }

  let(:chunk_size) { 400 }
  let(:chunk_overlap) { 100 }
  let(:chunking_profile) do
    ChunkingProfile.create!(
      method: chunking_method,
      size: chunk_size,
      overlap: chunk_overlap
    )
  end

  describe "#chunker_for" do
    context "with a :basic chunking method" do
      let(:chunking_method) { :basic }

      it "succeeds" do
        expect(subject.chunker_for(chunking_profile)).to be_a(Chunkers::BasicCharacterChunker)
      end
    end

    context "with a :bytes chunking method" do
      let(:chunking_method) { :bytes }

      it "succeeds for backwards compatibility" do
        expect(subject.chunker_for(chunking_profile)).to be_a(Chunkers::RecursiveTextChunker)
      end
    end

    context "with a :recursive_split chunking method" do
      let(:chunking_method) { :recursive_split }

      it "succeeds" do
        expect(subject.chunker_for(chunking_profile)).to be_a(Chunkers::RecursiveTextChunker)
      end
    end

    context "with unknown chunking method" do
      let(:chunking_method) { :unknown_method }

      it "raises an error" do
        expect { subject.chunker_for(chunking_profile) }.to raise_error(Chunkers::UnknownChunkingMethod)
      end
    end
  end
end
