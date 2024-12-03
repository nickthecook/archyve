RSpec.describe Converters do
  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { nil }
  let(:filename) { nil }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:doc) { create(:document, state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  describe "#find" do
    context "with a PDF file" do
      let(:filename) { "spec/fixtures/files/gnu_manifesto.pdf" }
      let(:file) { fixture_file_upload("gnu_manifesto.pdf") }

      it "succeeds" do
        expect(described_class.find(doc)).to be_a(Converters::PdfToText)
      end
    end

    context "with a markdown file" do
      let(:file) { fixture_file_upload("gnu_manifesto.md") }
      let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }

      it "fails" do
        expect { described_class.find(doc) }.to raise_error(Converters::UnsupportedDocumentFormat)
      end
    end
  end
end
