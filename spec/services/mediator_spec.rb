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

  describe "#ingest document" do
    context "with web link" do
      let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }

      it "fetches web page" do
        # Catching the message seems to prevent the actual method from being called
        # So limiting this to example
        allow(FetchWebDocumentJob).to receive("perform_async")

        subject.ingest(doc)

        expect(FetchWebDocumentJob).to have_received("perform_async").with(doc.id)
      end

      context "when web page has been fetched" do
        before do
          allow(ChunkDocumentJob).to receive("perform_async")
        end

        it "chunks document" do
          subject.ingest(doc)

          # Need to drain to cause the job to be run so I can check if the
          # chunking job was initiated after fetching
          FetchWebDocumentJob.drain

          expect(ChunkDocumentJob).to have_received("perform_async").with(doc.id)
        end
      end
    end

    context "with filename" do
      let(:file) { fixture_file_upload("gnu_manifesto.md", 'application/html') }
      let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }

      before do
        allow(ChunkDocumentJob).to receive("perform_async")
      end

      it "chunks document without web fetch needed" do
        subject.ingest(doc)

        expect(ChunkDocumentJob).to have_received("perform_async").with(doc.id)
      end
    end

    context "without filename or web link" do
      it "raises error" do
        expect { subject.ingest(doc) }.to raise_error(Mediator::DocumentHasNoFile)
      end
    end
  end
end
