RSpec.describe Mediator do
  subject { described_class }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { nil }
  let(:filename) { nil }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:doc) { Document.new(state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  describe "#ingest document" do
    after do
      FetchWebDocumentJob.clear
      ChunkDocumentJob.clear
    end

    context "with web link" do
      let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }
      # let(:doc) { create(:document, state: :created, filename: nil, link: "https://en.wikipedia.org/wiki/Tabloid_journalism", chunking_profile:) }

      it "fetches web page" do
        expect do
          subject.ingest(doc)
        end.to change(FetchWebDocumentJob.jobs, :size).by(1)
      end

      context "when web page has been fetched" do
        before do
          allow(Document).to receive(:find).and_return(doc)
        end

        it "chunks document" do
          expect do
            subject.ingest(doc)
            FetchWebDocumentJob.drain
          end.to change(ChunkDocumentJob.jobs, :size).by(1)
        end
      end
    end

    context "with filename" do
      let(:file) { fixture_file_upload("gnu_manifesto.md", 'application/html') }
      let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }
      # let(:doc) { create(:document, state: :created, filename: "spec/fixtures/files/gnu_manifesto.md", chunking_profile:) }

      it "chunks document" do
        expect do
          subject.ingest(doc)
        end.to change(ChunkDocumentJob.jobs, :size).by(1)
      end
    end
  end
end
