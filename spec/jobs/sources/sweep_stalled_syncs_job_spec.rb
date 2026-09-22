require "rails_helper"

RSpec.describe Sources::SweepStalledSyncsJob do
  subject(:job) { described_class.new }

  let(:source) { create(:folder_source, path: root) }
  let(:root) { Dir.mktmpdir("archyve-sweep-spec") }
  let(:result) { job.perform }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#perform" do
    context "with a running run that stopped reporting progress" do
      let!(:run) do
        create(:source_sync, source: source, status: "running", finished_at: nil,
          last_progress_at: 2.hours.ago)
      end

      it "retires it" do
        result
        expect(run.reload.status).to eq("failed")
      end

      it "records why" do
        result
        expect(run.reload.error).to eq("worker did not report back")
      end

      it "records when it gave up" do
        result
        expect(run.reload.finished_at).to be_present
      end

      # The whole point: due_for_sync excludes any source with a running scan,
      # so until this row moves the source can never sync again.
      it "frees the source to sync again" do
        result
        expect(Source.due_for_sync).to include(source)
      end
    end

    context "with a paused run that nothing resumed" do
      let!(:run) do
        create(:source_sync, source: source, status: "paused", finished_at: nil,
          last_progress_at: 2.hours.ago)
      end

      # Not `completed`: the scan never reached the end of its source, so its
      # view of what is there is partial. Retiring it as completed would claim
      # otherwise.
      it "retires it as failed" do
        result
        expect(run.reload.status).to eq("failed")
      end
    end

    context "with a stalled crawl that left item rows behind" do
      let!(:run) do
        create(:source_sync, source: source, status: "running", finished_at: nil,
          last_progress_at: 2.hours.ago)
      end

      before do
        run.items.create!(external_id: "https://site/a", disposition: :ok, status_code: 200)
        run.items.create!(external_id: "https://site/b", disposition: :timeout)
        run.items.create!(external_id: "https://site/unvisited")
      end

      it "keeps an account of how far it got" do
        result
        expect(run.reload.response_stats).to eq("200" => 1, "timeout" => 1)
      end

      # Nothing else ever collects these: the run is terminal, so no later pass
      # resumes its frontier, and a stalled crawl's is the bulk of the table.
      it "drops everything but the unanswered" do
        result
        expect(run.items.pluck(:external_id)).to eq(["https://site/b"])
      end
    end

    context "with a long scan that is still reporting progress" do
      let!(:run) do
        create(:source_sync, source: source, status: "running", started_at: 6.hours.ago,
          finished_at: nil, last_progress_at: 1.minute.ago)
      end

      it "leaves it alone" do
        result
        expect(run.reload.status).to eq("running")
      end
    end

    context "with a run that already failed for its own reason" do
      let!(:run) do
        create(:source_sync, source: source, status: "running", finished_at: nil,
          last_progress_at: 2.hours.ago, error: "Errno::ENOENT: no such directory")
      end

      it "keeps the original error rather than overwriting it" do
        result
        expect(run.reload.error).to eq("Errno::ENOENT: no such directory")
      end
    end

    context "with a completed run" do
      let!(:run) { create(:source_sync, source: source, status: "completed", started_at: 6.hours.ago) }

      it "leaves it alone" do
        result
        expect(run.reload.status).to eq("completed")
      end
    end
  end
end
