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
    context "with web link" do
      let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }

      it "fetches web page" do
        expect do
          subject.ingest(doc)
        end.to change(FetchWebDocumentJob.jobs, :size).by(1)
        Sidekiq::Worker.clear_all
      end

      context "when web page has been fetched" do
        it "chunks document" do
          doc.save
          subject.ingest(doc)

          expect { FetchWebDocumentJob.drain }.to change(ChunkDocumentJob.jobs, :size).by(1)
          Sidekiq::Worker.clear_all
        end
      end
    end

    context "with filename" do
      let(:file) { fixture_file_upload("gnu_manifesto.md", 'application/html') }
      let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }

      it "chunks document" do
        expect do
          subject.ingest(doc)
        end.to change(ChunkDocumentJob.jobs, :size).by(1)
        Sidekiq::Worker.clear_all
      end
    end
  end
end
