RSpec.describe Parsers::PdfViaText do
  subject { described_class.new(document) }

  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method) }
  let(:file) { fixture_file_upload("gnu_manifesto.pdf", 'application/pdf') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  context "when method is :basic" do
    it_behaves_like "all parsers"
  end

  context "when method is :recursive_split" do
    let(:chunking_method) { :recursive_split }

    it_behaves_like "all parsers"
  end

  describe "#chunks" do
    context "when file is not PDF" do
      let(:file) { fixture_file_upload("gnu_manifesto.md", 'text/markdown') }

      it "fails" do
        expect { subject.chunks }.to raise_error(StandardError)
      end
    end
  end
end
