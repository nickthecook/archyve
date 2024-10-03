RSpec.describe Parsers::Html do
  subject { described_class.new(document) }

  let(:chunking_profile) { create(:chunking_profile, method: :basic, size: 800) }
  let(:file) { fixture_file_upload("small_page.html", 'application/html') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }
  let(:text_type) { Chunkers::InputType::HTML }
  let(:text) { File.read(file) }

  context "when method is :basic" do
    it_behaves_like "all parsers"

    it "succeeds basic chunking" do
      puts subject.chunks[0].content
      expect(subject.chunks.count).to eq(1)
    end
  end

  context "when method is :recursive_split" do
    let(:chunking_profile) { create(:chunking_profile, method: :recursive_split) }

    it_behaves_like "all parsers"

    it "succeeds recursive chunking" do
      expect(subject.chunks.count).to eq(2)
    end
  end
end
