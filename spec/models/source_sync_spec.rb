require "rails_helper"

RSpec.describe SourceSync do
  subject(:sync) { create(:source_sync, source: source) }

  let(:source) { create(:folder_source, path: root) }
  let(:root) { Dir.mktmpdir("archyve-source-sync-spec") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#pipeline_statuses" do
    let(:result) { sync.pipeline_statuses }

    context "with documents in several states" do
      before do
        create(:document, source: source, source_sync: sync, status: "processed")
        create(:document, source: source, source_sync: sync, status: "processed")
        create(:document, source: source, source_sync: sync, status: "pending")
      end

      it "counts them by status" do
        expect(result).to eq({ "processed" => 2, "pending" => 1 })
      end
    end

    context "with documents from a different run" do
      before do
        create(:document, source: source, source_sync: sync, status: "processed")
        create(:document, source: source, source_sync: create(:source_sync, source: source),
          status: "failed")
      end

      it "counts only its own" do
        expect(result).to eq({ "processed" => 1 })
      end
    end

    # A scan that moves files between directories creates as many documents as it
    # tombstones. The tombstoned ones point at this run too, but were never given
    # to the pipeline, so counting them strands the progress bar half-empty.
    context "with documents this run tombstoned" do
      before do
        3.times { create(:document, source: source, source_sync: sync, status: "processed") }
        3.times { create(:document, source: source, source_sync: sync, status: "removed") }
      end

      it "counts only the documents it put through the pipeline" do
        expect(result).to eq({ "processed" => 3 })
      end
    end
  end

  describe "#processing_finished?" do
    let(:result) { sync.processing_finished? }

    context "when every document has been processed" do
      before { create(:document, source: source, source_sync: sync, status: "processed") }

      it { expect(result).to be(true) }
    end

    context "when a document is still queued" do
      before { create(:document, source: source, source_sync: sync, status: "pending") }

      it { expect(result).to be(false) }
    end

    context "when a document is mid-pipeline" do
      before { create(:document, source: source, source_sync: sync, status: "processing") }

      it { expect(result).to be(false) }
    end

    context "when a document failed" do
      before { create(:document, source: source, source_sync: sync, status: "failed") }

      it "counts as finished — failure is an outcome, not work in progress" do
        expect(result).to be(true)
      end
    end
  end

  describe "#duration" do
    context "with a finished run" do
      subject(:sync) do
        create(:source_sync, source: source, started_at: 10.seconds.ago, finished_at: Time.current)
      end

      it { expect(sync.duration).to be_within(1).of(10) }
    end

    context "with a run still going" do
      subject(:sync) { create(:source_sync, source: source, finished_at: nil) }

      it { expect(sync.duration).to be_nil }
    end
  end

  describe ".stalled" do
    context "with a run that started long ago and never reported back" do
      let!(:sync) { create(:source_sync, source: source, status: "running", started_at: 2.hours.ago) }

      it { expect(described_class.stalled).to include(sync) }
    end

    context "with a run that started recently" do
      let!(:sync) { create(:source_sync, source: source, status: "running", started_at: 1.minute.ago) }

      it { expect(described_class.stalled).not_to include(sync) }
    end

    context "with an old run that completed" do
      let!(:sync) do
        create(:source_sync, source: source, status: "completed", started_at: 2.hours.ago,
          finished_at: 2.hours.ago)
      end

      it { expect(described_class.stalled).not_to include(sync) }
    end
  end
end
