RSpec.describe Parsers::CommonMark do
  subject { described_class.new(document) }

  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method) }
  let(:file) { fixture_file_upload("small_doc.md", 'text/markdown; charset=UTF-8') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  context "when method is :basic" do
    it_behaves_like "all parsers"
  end

  context "when method is :recursive_split" do
    let(:chunking_method) { :recursive_split }

    it_behaves_like "all parsers"
  end
end
