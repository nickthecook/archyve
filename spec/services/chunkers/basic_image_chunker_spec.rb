RSpec.describe Chunkers::BasicImageChunker do
  subject { described_class.new(chunking_profile, Chunkers::InputType::JPG) }

  let(:chunk_size) { 1 }
  let(:chunk_overlap) { 0 }
  let(:chunking_profile) do
    ChunkingProfile.create!(
      method: :basic_image,
      size: chunk_size,
      overlap: chunk_overlap
    )
  end

  # TODO: Add something...  Should these work(?):
  # it_behaves_like "all chunkers"
  # it_behaves_like "chunkers supporting overlap"
end
