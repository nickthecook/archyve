RSpec.describe Parsers::Jpg do
  subject { described_class.new(document) }

  let(:chunking_method) { :basic_image }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 0) }
  let(:file) { fixture_file_upload("avatar.jpg", 'application/image') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  context "when method is :basic_image" do
    it "succeeds basic image chunking" do
      expect(subject.chunks.count).to eq(1)
    end
  end
end
