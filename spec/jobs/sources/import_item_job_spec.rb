require "rails_helper"

RSpec.describe Sources::ImportItemJob do
  subject(:job) { described_class.new }

  let(:source) { create(:folder_source, path: root) }
  let(:root) { Dir.mktmpdir("archyve-import-spec") }
  let(:content) { "# Heading\n\nBody." }
  let(:document) do
    create(:document, source: source, external_id: "doc.md", content_type: "text/markdown", status: "pending")
  end
  let(:version) { "42-1767225600" }
  let(:result) { job.perform(document, version) }

  before { File.write(File.join(root, "doc.md"), content) }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#perform" do
    context "with a document that has never been imported" do
      it "attaches the source bytes" do
        result
        expect(document.file.download).to eq(content)
      end

      it "records the version token it imported" do
        expect { result }.to change { document.reload.source_version }.to(version)
      end

      it "records the content checksum" do
        result
        expect(document.reload.source_metadata["checksum"]).to eq(Digest::SHA256.hexdigest(content))
      end

      it "hands the document to the ingestion pipeline" do
        expect { result }.to have_enqueued_job(ProcessDocumentJob)
      end
    end

    context "when the source feeds a collection" do
      let(:collection) { create(:collection) }

      before { source.collections << collection }

      it "files the document into it" do
        result
        expect(collection.documents).to include(document)
      end

      it "files it as a feed membership" do
        result
        expect(CollectionMembership.find_by(document: document, collection: collection).origin).to eq("feed")
      end
    end

    context "when a person already filed the document into a collection" do
      let(:collection) { create(:collection) }

      before do
        source.collections << collection
        CollectionMembership.add(document: document, collection: collection)
      end

      it "upgrades the membership to source-owned" do
        result
        expect(CollectionMembership.find_by(document: document, collection: collection).origin).to eq("feed")
      end
    end

    context "when the version token moved but the content is identical" do
      let(:document) do
        create(:document, source: source, external_id: "doc.md", status: "processed",
          source_version: "old-token", source_metadata: { "checksum" => Digest::SHA256.hexdigest(content) })
      end

      it "records the new version token" do
        expect { result }.to change { document.reload.source_version }.to(version)
      end

      it "does not re-run the pipeline" do
        expect { result }.not_to have_enqueued_job(ProcessDocumentJob)
      end

      it "leaves the document processed" do
        result
        expect(document.reload.status).to eq("processed")
      end
    end

    context "when the content is identical but the last pipeline run failed" do
      let(:document) do
        create(:document, source: source, external_id: "doc.md", status: "failed",
          source_version: "old-token", source_metadata: { "checksum" => Digest::SHA256.hexdigest(content) })
      end

      it "processes it rather than skipping" do
        expect { result }.to have_enqueued_job(ProcessDocumentJob)
      end
    end

    context "when the source file cannot be read" do
      # `document` is referenced first so the source is created while its
      # path still validates — otherwise the failure under test would be the
      # source failing to save, not the read failing.
      before do
        document
        FileUtils.remove_entry(root)
      end

      it "re-raises so the failure is recorded" do
        expect { result }.to raise_error(Errno::ENOENT)
      end

      it "marks the document failed" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(document.reload.status).to eq("failed")
      end
    end
  end
end
