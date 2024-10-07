RSpec.describe Chunkers::RecursiveTextChunker do
  subject { described_class.new(chunking_profile, Chunkers::InputType::PLAIN_TEXT) }

  let(:chunk_size) { 100 }
  let(:chunk_overlap) { 20 }
  let(:chunking_profile) do
    ChunkingProfile.create!(
      method: :basic,
      size: chunk_size,
      overlap: chunk_overlap
    )
  end

  describe "for commonmark text chunking" do
    it_behaves_like "all chunkers"
    it_behaves_like "chunkers supporting overlap"
  end
end
