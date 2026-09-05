require "rails_helper"

RSpec.describe Ingestion::DocumentUploader do
  subject(:upload) do
    described_class.call(file: file, filename: "sample.md", content_type: "text/markdown", collections: collections)
  end

  let(:content) { "# Title\n\nBody text." }
  let(:file) { StringIO.new(content) }
  let(:collections) { [] }

  before { allow(ProcessDocumentJob).to receive(:perform_later) }

  describe ".call" do
    context "with a new file" do
      it "creates a document" do
        expect { upload }.to change(Document, :count).by(1)
      end

      it "owns it with the manual upload connector" do
        expect(upload.connector).to be_a(Connectors::ManualUpload)
      end

      it "attaches the uploaded bytes" do
        expect(upload.file).to be_attached
      end

      it "starts the document pending" do
        expect(upload.status).to eq("pending")
      end

      it "sets external_id to the content hash" do
        expect(upload.external_id).to eq(Digest::SHA256.hexdigest(content))
      end

      it "enqueues the pipeline" do
        upload
        expect(ProcessDocumentJob).to have_received(:perform_later).with(instance_of(Document))
      end
    end

    context "when the same bytes were already uploaded" do
      before do
        described_class.call(file: StringIO.new(content), filename: "sample.md", content_type: "text/markdown")
      end

      it "does not create a duplicate document" do
        expect { upload }.not_to change(Document, :count)
      end

      it "returns the existing document" do
        expect(upload.external_id).to eq(Digest::SHA256.hexdigest(content))
      end
    end

    context "with target collections" do
      let(:collection) { create(:collection) }
      let(:collections) { [collection] }

      it "adds the document to the collection" do
        expect(upload.collections).to contain_exactly(collection)
      end

      it "records the membership as manually sourced" do
        membership = upload.collection_memberships.first
        expect(membership.source).to eq("manual")
      end
    end
  end
end
