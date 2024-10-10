RSpec.describe Parsers::Jpg do
  subject { described_class.new(document) }

  let(:chunking_profile) { create(:chunking_profile, method: :basic, size: 800) }
  let(:file) { fixture_file_upload("avatar.jpg", 'application/image') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  context "when method is :basic" do
    it_behaves_like "all parsers"

    xit "succeeds basic chunking" do # TODO
      expect(subject.chunks.count).to eq(17)
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
