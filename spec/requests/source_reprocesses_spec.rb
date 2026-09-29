require "rails_helper"

RSpec.describe "Source reprocessing", type: :request do
  let(:source) { create(:source) }

  # Reaching a source at all is a grant; reprocessing it is work on the source,
  # so the examples below start from someone who manages this one.
  before { create(:source_user, :admin, source:, user: current_user) }

  def document_with_file
    create(:document, source:, status: "processed").tap do |doc|
      doc.file.attach(io: StringIO.new("body"), filename: "d.md", content_type: "text/markdown")
    end
  end

  describe "POST /sources/:id/reprocess" do
    context "with documents to re-extract" do
      before { document_with_file }

      it "opens a run" do
        expect { post reprocess_source_path(source) }.to change { source.reprocesses.count }.by(1)
      end

      it "records how many the run is for, so progress means something" do
        post reprocess_source_path(source)
        expect(source.reprocesses.last.total).to eq(1)
      end

      it "starts the walker rather than the conversions, which it hands over in windows" do
        expect { post reprocess_source_path(source) }.to have_enqueued_job(Sources::ReprocessJob)
      end
    end

    context "when a run is already going" do
      before do
        document_with_file
        create(:source_reprocess, source:, total: 1)
      end

      it "refuses rather than opening a second" do
        expect { post reprocess_source_path(source) }.not_to change { source.reprocesses.count }
      end

      it "says why" do
        post reprocess_source_path(source)
        expect(flash[:alert]).to match(/already running/i)
      end
    end

    context "when the source has nothing re-extractable" do
      before { create(:document, source:, status: "processed") }

      it "refuses rather than opening an empty run" do
        expect { post reprocess_source_path(source) }.not_to change { source.reprocesses.count }
      end
    end

    context "as a reader" do
      before do
        document_with_file
        sign_in(create(:user))
      end

      it "is turned away, because reprocessing is work on the source" do
        post reprocess_source_path(source)
        expect(response).to redirect_to(root_path)
      end

      it "opens no run" do
        expect { post reprocess_source_path(source) }.not_to change { source.reprocesses.count }
      end
    end
  end

  describe "POST /sources/:id/cancel_reprocess" do
    context "with a run going" do
      let!(:run) { create(:source_reprocess, source:, total: 5) }

      it "stops it handing over anything more" do
        expect { post cancel_reprocess_source_path(source) }.to change { run.reload.status }.to("cancelled")
      end

      it "says that queued work still finishes, because it does" do
        post cancel_reprocess_source_path(source)
        expect(flash[:notice]).to match(/already queued will finish/i)
      end
    end

    context "with no run going" do
      it "says so rather than pretending to stop one" do
        post cancel_reprocess_source_path(source)
        expect(flash[:alert]).to match(/no reprocess/i)
      end
    end
  end
  describe "GET /sources/:id" do
    before { document_with_file }

    context "with no run going" do
      it "offers to start one, saying how many documents that is" do
        get source_path(source)
        expect(response.body).to include("Reprocess all").and include("Reprocess 1 documents?")
      end
    end

    context "with a run going" do
      before { create(:source_reprocess, source:, total: 40, enqueued: 12) }

      it "reports progress rather than offering to start a second" do
        get source_path(source)
        expect(response.body).to include("12 of 40 handed over")
      end

      it "offers to stop it" do
        get source_path(source)
        expect(response.body).to include("Stop")
      end

      it "keeps the region polling so it can be watched" do
        get source_path(source)
        expect(response.body).to include('data-progress-terminal-value="false"')
      end
    end

    context "when a run has been stopped but its last window still has docs queued up" do
      before do
        create(:source_reprocess, source:, total: 40, enqueued: 12, status: "cancelled", finished_at: Time.current)
        source.documents.update_all(status: "processing")
      end

      it "keeps watching, because those documents are still moving" do
        get source_path(source)
        expect(response.body).to include('data-progress-terminal-value="false"')
      end

      it "says the run was stopped rather than reverting to the idle wording" do
        get source_path(source)
        expect(response.body).to include("Last run stopped")
      end
    end

    context "when nothing is running and nothing is moving" do
      it "stops polling" do
        get source_path(source)
        expect(response.body).to include('data-progress-terminal-value="true"')
      end
    end
  end
  describe "GET /sources" do
    context "with a run going" do
      before { create(:source_reprocess, source:, total: 40) }

      it "says so on the source's card" do
        get sources_path
        expect(response.body).to include("reprocessing")
      end
    end

    # A manual-upload source has no sync status at all, so this is the only
    # thing its card can say about what it is doing.
    context "with a run going on a source that never scans" do
      let(:source) { create(:source) }

      before { create(:source_reprocess, source:, total: 40) }

      it "still says so" do
        get sources_path
        expect(response.body).to include("reprocessing")
      end
    end

    context "with no run going" do
      it "says nothing about reprocessing" do
        get sources_path
        expect(response.body).not_to include("reprocessing")
      end
    end

    describe "keeping the list current" do
      context "while a run is going" do
        before { create(:source_reprocess, source:, total: 40) }

        it "polls, so the badge appears and clears without a reload" do
          get sources_path
          expect(response.body).to include('data-progress-terminal-value="false"')
        end
      end

      context "while a scan is going" do
        before { create(:source_sync, source:, status: "running") }

        it "polls too, since the same cards carry the scan status" do
          get sources_path
          expect(response.body).to include('data-progress-terminal-value="false"')
        end
      end

      context "when every source has settled" do
        before { create(:source_sync, source:, status: "completed") }

        it "stops polling rather than redrawing a static page for every visitor" do
          get sources_path
          expect(response.body).to include('data-progress-terminal-value="true"')
        end
      end
    end
  end
end
