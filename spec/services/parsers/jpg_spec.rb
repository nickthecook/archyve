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

  # TODO: Determine expected bahavior of the other methods.
  #       Maybe ':basic' always means ':basic_image'?

  # context "when method is :basic" do
  #   it_behaves_like "all parsers"

  #   it "succeeds basic chunking" do
  #     expect(subject.chunks.count).to eq(1)
  #   end
  # end

  # context "when method is :recursive_split" do
  #   let(:chunking_profile) { create(:chunking_profile, method: :recursive_split) }

  #   it_behaves_like "all parsers"

  #   it "succeeds recursive chunking" do
  #     expect(subject.chunks.count).to eq(149)
  #   end
end
