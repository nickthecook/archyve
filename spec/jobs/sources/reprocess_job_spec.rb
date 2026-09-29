require "rails_helper"

RSpec.describe Sources::ReprocessJob do
  subject(:run_job) { described_class.perform_now(run) }

  let(:source) { create(:source) }
  let(:run) { create(:source_reprocess, source:, total: documents.size) }

  def document_with_file(status: "processed")
    create(:document, source:, status:).tap do |doc|
      doc.file.attach(io: StringIO.new("body"), filename: "d.md", content_type: "text/markdown")
    end
  end

  describe "#perform" do
    let!(:documents) { Array.new(3) { document_with_file } }

    context "with documents to hand over" do
      it "enqueues one conversion per document" do
        expect { run_job }.to have_enqueued_job(ProcessDocumentJob).exactly(3).times
      end

      it "queues them behind anything a person is waiting on" do
        expect { run_job }
          .to have_enqueued_job(ProcessDocumentJob).at_priority(described_class::PRIORITY).exactly(3).times
      end

      it "marks them pending without rebuilding every document's page to say so" do
        expect { run_job }.to change { documents.each(&:reload).map(&:status).uniq }.to(["pending"])
      end

      it "records how far the handover got" do
        expect { run_job }.to change { run.reload.enqueued }.from(0).to(3)
      end

      it "schedules itself to top the window up" do
        expect { run_job }.to have_enqueued_job(described_class)
      end
    end

    context "when the run was stopped" do
      before { run.cancel! }

      it "hands over nothing further" do
        expect { run_job }.not_to have_enqueued_job(ProcessDocumentJob)
      end

      it "does not schedule itself again" do
        expect { run_job }.not_to have_enqueued_job(described_class)
      end
    end

    context "when the source's window is already full" do
      before { stub_const("#{described_class}::WINDOW", 0) }

      it "hands over nothing this pass" do
        expect { run_job }.not_to have_enqueued_job(ProcessDocumentJob)
      end

      it "keeps the run going, because the work is still to come" do
        run_job
        expect(run.reload).to be_running
      end
    end

    context "when every document has been handed over" do
      before { run.update!(cursor: Document.maximum(:id)) }

      it "completes the run" do
        expect { run_job }.to change { run.reload.status }.to("completed")
      end

      it "stops scheduling itself" do
        expect { run_job }.not_to have_enqueued_job(described_class)
      end
    end

    context "with a document whose file is gone" do
      let!(:fileless) { create(:document, source:, status: "processed") }

      it "leaves it alone, because there is nothing to re-extract" do
        run_job
        expect(fileless.reload.status).to eq("processed")
      end
    end

    context "with a tombstoned document" do
      let!(:removed) { document_with_file(status: "removed") }

      it "leaves it alone, because it is no longer in the archive" do
        run_job
        expect(removed.reload.status).to eq("removed")
      end
    end
  end
end
