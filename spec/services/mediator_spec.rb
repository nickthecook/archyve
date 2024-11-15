RSpec.describe Mediator do
  subject { described_class }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { nil }
  let(:filename) { nil }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:doc) { create(:document, state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  describe "#ingest" do
    context "with web link" do
      let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }

      before do
        allow(FetchWebDocumentJob).to receive("perform_async")
      end

      it "fetches web page" do
        subject.ingest(doc)

        expect(FetchWebDocumentJob).to have_received("perform_async").with(doc.id)
      end
    end

    context "with a PDF file" do
      let(:filename) { "spec/fixtures/files/gnu_manifesto.pdf" }
      let(:file) { fixture_file_upload("gnu_manifesto.pdf") }

      before do
        allow(ConvertDocumentJob).to receive("perform_async")
      end

      it "converts document" do
        subject.ingest(doc)

        expect(ConvertDocumentJob).to have_received("perform_async").with(doc.id)
      end
    end

    context "with markdown file" do
      let(:file) { fixture_file_upload("gnu_manifesto.md") }
      let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }

      before do
        allow(ChunkDocumentJob).to receive("perform_async")
      end

      it "chunks document without web fetch needed" do
        subject.ingest(doc)

        expect(ChunkDocumentJob).to have_received("perform_async").with(doc.id)
      end
    end

    context "with audio file" do
      let(:file) { fixture_file_upload("sample-3s.mp3") }
      let(:filename) { "spec/fixtures/files/sample-3s.mp3" }

      it "fails" do
        expect { subject.ingest(doc) }.to raise_error(Mediator::CannotIngestDocument)
      end
    end

    context "with image file" do
      let(:filename) { "spec/fixtures/files/avatar.jpg" }
      let(:file) { fixture_file_upload("avatar.jpg") }

      it "fails" do
        expect { subject.ingest(doc) }.to raise_error(Mediator::CannotIngestDocument)
      end
    end

    context "without filename or web link" do
      it "fails" do
        expect { subject.ingest(doc) }.to raise_error(Mediator::CannotIngestDocument)
      end
    end
  end
end
