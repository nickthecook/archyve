require "rails_helper"

RSpec.describe Ingestion::DocumentUploader do
  subject(:upload) do
    described_class.call(
      file: file, user: user, filename: "sample.md", content_type: "text/markdown", collections: collections
    )
  end

  let(:content) { "# Title\n\nBody text." }
  let(:file) { StringIO.new(content) }
  let(:collections) { [] }
  let(:user) { create(:user) }

  before { allow(ProcessDocumentJob).to receive(:perform_later) }

  describe ".call" do
    context "with a new file" do
      it "creates a document" do
        expect { upload }.to change(Document, :count).by(1)
      end

      it "owns it with a manual upload source" do
        expect(upload.source).to be_a(Sources::ManualUpload)
      end

      it "owns that source with the uploader" do
        expect(upload.source.user).to eq(user)
      end

      it "names the source for the uploader" do
        expect(upload.source.name).to eq("Uploads — #{user.email_address}")
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

    context "when the same person uploads a second, different file" do
      before do
        described_class.call(file: StringIO.new("something else"), user: user, filename: "other.md")
      end

      it "reuses their existing upload source" do
        expect { upload }.not_to change(Sources::ManualUpload, :count)
      end
    end

    context "when a different person uploads" do
      let(:other_user) { create(:user) }

      before do
        described_class.call(file: StringIO.new(content), user: other_user, filename: "sample.md")
      end

      it "gives them their own upload source" do
        expect(upload.source).not_to eq(Sources::ManualUpload.find_by(user: other_user))
      end

      # Dedup is per-source, and sources are now per-person, so identical bytes
      # from two people are two documents. Deliberate: one person removing their
      # upload must not remove the other's.
      it "does not dedup across people" do
        expect { upload }.to change(Document, :count).by(1)
      end
    end

    context "when the same bytes were already uploaded by the same person" do
      before do
        described_class.call(file: StringIO.new(content), user: user, filename: "sample.md")
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

      it "records the membership as manually originated" do
        membership = upload.collection_memberships.first
        expect(membership.origin).to eq("manual")
      end
    end

    # Re-uploading a file the archive already holds is how someone asks for a
    # different result: a setting changed, or the last attempt failed. The bytes
    # are the same, but the request isn't, and answering it with silence was the
    # bug — the flash said "Processing…" while nothing ran.
    describe "re-uploading a file the archive already holds" do
      subject(:upload) do
        described_class.call(file: StringIO.new(content), user: user, filename: "sample.md", ocr: ocr)
      end

      let(:ocr) { nil }
      let(:status) { "processed" }

      # Built directly rather than by uploading first, so the spy below counts
      # only what *this* upload enqueues.
      let!(:existing) do
        create(
          :document, :with_file,
          source: Sources::ManualUpload.create!(name: "Uploads", user: user),
          external_id: Digest::SHA256.hexdigest(content),
          status: status
        )
      end

      context "when this upload turns OCR off" do
        let(:ocr) { false }

        it "records the new choice on the document" do
          expect(upload.ocr).to be(false)
        end

        it "reprocesses, since the chunks it holds were made the other way" do
          upload
          expect(ProcessDocumentJob).to have_received(:perform_later).with(existing)
        end

        it "puts it back in the queue" do
          expect(upload.status).to eq("pending")
        end
      end

      context "when this upload asks for the same OCR setting it already had" do
        let(:ocr) { true }

        it "stays the cheap no-op, rather than spending minutes of docling" do
          upload
          expect(ProcessDocumentJob).not_to have_received(:perform_later).with(existing)
        end

        it "leaves it processed" do
          expect(upload.status).to eq("processed")
        end
      end

      # What the old failed_note told people to do, which until now did nothing.
      context "when the previous attempt failed" do
        let(:status) { "failed" }

        before do
          existing.record_failure!(
            Ingestion::Outcome.new(stage: "extract", kind: "unreachable", detail: "docling did not respond")
          )
        end

        it "tries again" do
          upload
          expect(ProcessDocumentJob).to have_received(:perform_later).with(existing)
        end

        it "clears the failure it is retrying, so the page stops showing it as current" do
          expect(upload).to have_attributes(status: "pending", outcome_kind: nil, outcome_detail: nil)
        end
      end

      context "when it processed cleanly and this upload says nothing new" do
        it "does nothing" do
          upload
          expect(ProcessDocumentJob).not_to have_received(:perform_later).with(existing)
        end
      end
    end

    context "when identical bytes exist but not yet in the target collection" do
      let(:collection) { create(:collection) }
      let(:collections) { [collection] }

      before { described_class.call(file: StringIO.new(content), user: user, filename: "sample.md") }

      it "adds the existing document to the collection without re-ingesting" do
        expect { upload }.not_to change(Document, :count)
        expect(upload.collections).to contain_exactly(collection)
      end
    end
  end
end
