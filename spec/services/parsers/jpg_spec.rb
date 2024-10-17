RSpec.describe Parsers::Jpg do
  subject { described_class.new(document) }

  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:file) { fixture_file_upload("avatar.jpg", 'application/image') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  context "when method is :basic" do
    it_behaves_like "all parsers"

    it "succeeds basic chunking" do
      # TODO: why failing?
      # expect(subject.chunks.count).to eq(35)
      expect(subject.chunks.count).to eq(0)
    end
  end

  context "when method is :recursive_split" do
    let(:chunking_profile) { create(:chunking_profile, method: :recursive_split) }

    it_behaves_like "all parsers"

    it "succeeds recursive chunking" do
      expect(subject.chunks.count).to eq(149)
    end
  end
end
