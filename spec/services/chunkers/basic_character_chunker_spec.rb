RSpec.describe Chunkers::BasicCharacterChunker do
  subject { described_class.new(chunking_profile) }

  let(:text) { file_fixture('small_doc.md').read }
  let(:text_type) { Chunkers::InputType::PLAIN_TEXT }
  let(:chunk_size) { 100 }
  let(:chunk_overlap) { 20 }
  let(:chunking_profile) do
    ChunkingProfile.create!(
      method: :basic,
      size: chunk_size,
      overlap: chunk_overlap
    )
  end

  it_behaves_like "all chunkers"
  it_behaves_like "chunkers supporting overlap"
end
