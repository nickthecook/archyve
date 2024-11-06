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

  shared_examples "supported_chunking_method" do |method, chunker_class|
    context "with #{method} chunking method" do
      let(:chunking_method) { method }

      it "succeeds" do
        expect(subject.chunker_for(chunking_profile, Chunkers::InputType::PLAIN_TEXT)).to be_a(chunker_class)
      end
    end
  end

  describe "#chunker_for" do
    include_examples "supported_chunking_method", :basic, Chunkers::BasicCharacterChunker
    include_examples "supported_chunking_method", :basic_image, Chunkers::BasicImageChunker
    include_examples "supported_chunking_method", :bytes, Chunkers::RecursiveTextChunker
    include_examples "supported_chunking_method", :recursive_split, Chunkers::RecursiveTextChunker

    context "with unknown chunking method" do
      let(:chunking_method) { :unknown_method }

      it "raises an error" do
        expect { subject.chunker_for(chunking_profile, Chunkers::InputType::PLAIN_TEXT) }.to raise_error(Chunkers::UnknownChunkingMethod)
      end
    end
  end
end
