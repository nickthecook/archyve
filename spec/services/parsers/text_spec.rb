RSpec.describe Parsers::Text do
  subject { described_class.new(document) }

  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method) }
  let(:file) { fixture_file_upload("small_file.txt") }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  context "when method is :basic" do
    it_behaves_like "all parsers"

    it "succeeds basic chunking" do
      expect(subject.chunks.count).to eq(2) # for 295 bytes
    end
  end

  context "when method is :recursive_split" do
    let(:chunking_method) { :recursive_split }
    let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 1000) }

    it_behaves_like "all parsers"

    it "succeeds recursive split chunking" do
      expect(subject.chunks.count).to eq(1)
    end
  end
end
