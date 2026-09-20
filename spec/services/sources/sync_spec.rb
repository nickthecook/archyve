require "rails_helper"

RSpec.describe Sources::Sync do
  subject(:sync) { described_class.new(source) }

  let(:source) { create(:folder_source, path: root) }
  let(:root) { Dir.mktmpdir("archyve-sync-spec") }
  let(:result) { sync.call }

  def write(relative, content: "hello")
    absolute = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, content)
    absolute
  end

  # The version token the source currently reports for a file, so a spec can
  # set up a document that is genuinely up to date.
  def current_version(relative)
    source.each_item.find { |item| item.external_id == relative }.version
  end

  # Turn the source into one that honours the `resumable_scan?` contract: it
  # remembers what it has already handed over and picks up from there on the
  # next pass, rather than enumerating from the top.
  #
  # Two details are the contract rather than the fake. An item is marked taken
  # *before* it is yielded, and the cursor is persisted from an `ensure` —
  # because Sources::Sync stops a scan with `break`, which leaves `each_item`
  # immediately and would otherwise lose the very item that hit the budget. A
  # source that got either wrong would re-yield across passes and double-count
  # itself, which is what `resumable_scan?` defaulting to false protects
  # everything else from.
  def make_resumable(external_ids)
    items = external_ids.map do |id|
      Source::Item.new(external_id: id, version: "v1", title: id, content_type: "text/markdown")
    end

    allow(source).to receive(:resumable_scan?).and_return(true)
    allow(source).to receive(:each_item) do |&block|
      taken = source.state.fetch("taken", [])

      begin
        items.each do |item|
          next if taken.include?(item.external_id)

          taken << item.external_id
          block.call(item)
        end
      ensure
        source.update!(state: source.state.merge("taken" => taken))
      end
    end
  end

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#call" do
    context "with a file the source has never seen" do
      before { write("new.md") }

      it "creates a document for it" do
        expect { result }.to change { source.documents.count }.from(0).to(1)
      end

      it "identifies the document by its path relative to the root" do
        result
        expect(source.documents.sole.external_id).to eq("new.md")
      end

      it "counts it as created" do
        expect(result.created_count).to eq(1)
      end

      it "enqueues an import for it" do
        expect { result }.to have_enqueued_job(Sources::ImportItemJob)
      end

      it "leaves source_version unset until the import succeeds" do
        result
        expect(source.documents.sole.source_version).to be_nil
      end

      it "attributes the document to the run" do
        expect(source.documents.sole.source_sync).to eq(result) if result
      end
    end

    context "with a file already ingested at its current version" do
      before do
        write("stable.md")
        create(:document, source: source, external_id: "stable.md",
          source_version: current_version("stable.md"), status: "processed")
      end

      it "counts it as unchanged" do
        expect(result.unchanged_count).to eq(1)
      end

      it "does not enqueue an import" do
        expect { result }.not_to have_enqueued_job(Sources::ImportItemJob)
      end
    end

    context "with an item the source now describes differently, at an unchanged version" do
      before do
        write("moved.md")
        create(:document, source: source, external_id: "moved.md", path: "old/place",
          source_version: current_version("moved.md"), status: "processed")
      end

      it "still counts it as unchanged" do
        expect(result.unchanged_count).to eq(1)
      end

      # The point of writing the description on this branch: a Bookstack book
      # rename moves every page's path, and refetching all of them to discover
      # the bytes are identical is what a path-in-the-version-token scheme costs.
      it "rewrites the description without refetching the bytes" do
        expect { result }.not_to have_enqueued_job(Sources::ImportItemJob)
        expect(source.documents.sole.path).to be_nil
      end
    end

    context "with a file whose version token has moved" do
      before do
        write("changed.md")
        create(:document, source: source, external_id: "changed.md",
          source_version: "stale-token", status: "processed")
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end

      it "enqueues an import for it" do
        expect { result }.to have_enqueued_job(Sources::ImportItemJob)
      end

      it "keeps the old source_version until the import succeeds" do
        result
        expect(source.documents.sole.source_version).to eq("stale-token")
      end
    end

    context "with a document whose file is gone from the folder" do
      let!(:document) do
        create(:document, source: source, external_id: "deleted.md",
          source_version: "v1", status: "processed")
      end

      it "tombstones it" do
        result
        expect(document.reload.status).to eq("removed")
      end

      it "counts it as removed" do
        expect(result.removed_count).to eq(1)
      end

      it "destroys its chunks" do
        create(:chunk, document: document, position: 0)
        expect { result }.to change { document.chunks.count }.from(1).to(0)
      end
    end

    context "with a document whose last ingest failed" do
      before do
        write("broken.md")
        create(:document, source: source, external_id: "broken.md",
          source_version: current_version("broken.md"), status: "failed")
      end

      it "re-imports it even though the version token is unchanged" do
        expect { result }.to have_enqueued_job(Sources::ImportItemJob)
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end
    end

    context "with a file the source reports but declines to ingest" do
      let(:oversized) do
        Source::Item.new(
          external_id: "huge.pdf", version: "v1", title: "huge.pdf",
          content_type: "application/pdf", skip_reason: "too big"
        )
      end

      before { allow(source).to receive(:each_item) { |&block| block.call(oversized) } }

      it "counts it as skipped" do
        expect(result.skipped_count).to eq(1)
      end

      it "does not import it" do
        expect { result }.not_to have_enqueued_job(Sources::ImportItemJob)
      end

      it "does not create a document for it" do
        expect { result }.not_to change { source.documents.count }
      end
    end

    context "when a document's file is still there but has grown too large to ingest" do
      let(:oversized) do
        Source::Item.new(
          external_id: "grew.md", version: "v2", title: "grew.md",
          content_type: "text/markdown", skip_reason: "too big"
        )
      end
      let!(:document) do
        create(:document, source: source, external_id: "grew.md", source_version: "v1", status: "processed")
      end

      before { allow(source).to receive(:each_item) { |&block| block.call(oversized) } }

      it "leaves the existing document alone rather than tombstoning it" do
        result
        expect(document.reload.status).to eq("processed")
      end

      it "does not count it as removed" do
        expect(result.removed_count).to eq(0)
      end

      it "counts it as stale — the archive holds a version the source has moved past" do
        expect(result.stale_count).to eq(1)
      end

      it "does not count it as skipped, which would imply we don't have it" do
        expect(result.skipped_count).to eq(0)
      end

      it "does not record the version it could not ingest" do
        result
        expect(document.reload.source_version).to eq("v1")
      end
    end

    context "when a document is up to date but its file is now uningestable" do
      let(:oversized) do
        Source::Item.new(
          external_id: "frozen.md", version: "v1", title: "frozen.md",
          content_type: "text/markdown", skip_reason: "too big"
        )
      end

      before do
        create(:document, source: source, external_id: "frozen.md", source_version: "v1", status: "processed")
        allow(source).to receive(:each_item) { |&block| block.call(oversized) }
      end

      it "counts it as unchanged, because the document still matches the source" do
        expect(result.unchanged_count).to eq(1)
      end

      it "is not stale" do
        expect(result.stale_count).to eq(0)
      end
    end

    # The payoff of never writing a skipped item's version: raising the limit
    # later makes the file look changed again, so it gets picked up.
    context "when a previously skipped file becomes ingestable again" do
      let!(:document) do
        create(:document, source: source, external_id: "big.md", source_version: "v1", status: "processed")
      end

      before do
        write("big.md", content: "now within the limit")
        allow(source).to receive(:each_item).and_call_original
      end

      it "re-imports it" do
        expect { result }.to have_enqueued_job(Sources::ImportItemJob)
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end
    end

    context "with a tombstoned document whose file has come back" do
      before do
        write("restored.md")
        create(:document, source: source, external_id: "restored.md",
          source_version: current_version("restored.md"), status: "removed")
      end

      it "re-imports it even though the version token is unchanged" do
        expect { result }.to have_enqueued_job(Sources::ImportItemJob)
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end
    end

    context "when a removed document was fed into a collection by this source" do
      let(:collection) { create(:collection) }
      let(:document) do
        create(:document, source: source, external_id: "gone.md", status: "processed")
      end

      before { CollectionMembership.feed!(document: document, collection: collection) }

      it "retracts the feed membership" do
        result
        expect(CollectionMembership.find_by(document: document, collection: collection)).not_to be_active
      end
    end

    context "when a removed document was filed into a collection by a person" do
      let(:collection) { create(:collection) }
      let(:document) do
        create(:document, source: source, external_id: "gone.md", status: "processed")
      end

      before { CollectionMembership.add(document: document, collection: collection) }

      it "leaves the manual membership alone" do
        result
        expect(CollectionMembership.find_by(document: document, collection: collection)).to be_active
      end
    end

    context "when one item fails and others are fine" do
      # An item the source reports but that cannot become a Document — here
      # because it carries no external_id, the one thing every source must
      # supply. Reconciling it raises, which is the case this context is about.
      let(:broken) do
        Source::Item.new(external_id: "", version: "v1", title: "broken", content_type: "text/plain")
      end

      before do
        write("good.md")
        good = source.each_item.to_a
        allow(source).to receive(:each_item) do |&block|
          good.each(&block)
          block.call(broken)
        end
      end

      it "still creates the healthy document" do
        result
        expect(source.documents.pluck(:external_id)).to eq(["good.md"])
      end

      it "counts the failure" do
        expect(result.failed_count).to eq(1)
      end

      it "does not tombstone the item it failed to read" do
        expect(result.removed_count).to eq(0)
      end
    end

    context "with a successful scan" do
      before { write("a.md") }

      it "marks the run completed" do
        expect(result.status).to eq("completed")
      end

      it "records when it finished" do
        expect(result.finished_at).to be_present
      end

      it "stamps the source's last_synced_at" do
        expect { result }.to change { source.reload.last_synced_at }.from(nil)
      end
    end

    describe "stamping what the scan saw" do
      context "with a file the source has never seen" do
        before { write("new.md") }

        it "stamps the run on the document it created" do
          run = result
          expect(source.documents.sole.last_seen_sync).to eq(run)
        end
      end

      context "with a file already ingested at its current version" do
        let!(:document) do
          write("stable.md")
          create(:document, source: source, external_id: "stable.md",
            source_version: current_version("stable.md"), status: "processed")
        end

        # The branch almost every document takes on almost every scan. An
        # unstamped document is a tombstoned one.
        it "stamps the run even though nothing about the document changed" do
          result
          expect(document.reload.last_seen_sync).to eq(result)
        end
      end

      context "with a document the source reports but declines to ingest" do
        let(:oversized) do
          Source::Item.new(external_id: "grew.md", version: "v2", title: "grew.md",
            content_type: "text/markdown", skip_reason: "too big")
        end
        let!(:document) do
          create(:document, source: source, external_id: "grew.md", source_version: "v1", status: "processed")
        end

        before { allow(source).to receive(:each_item) { |&block| block.call(oversized) } }

        it "stamps it, so tightening a limit cannot tombstone it" do
          result
          expect(document.reload.last_seen_sync).to eq(result)
        end
      end

      context "with a document no scan has ever stamped" do
        let!(:document) do
          create(:document, source: source, external_id: "ancient.md", source_version: "v1",
            status: "processed", last_seen_sync: nil)
        end

        # `where.not(last_seen_sync_id: run.id)` would silently spare these:
        # NULL <> 5 is NULL, not true.
        it "tombstones it rather than passing over the null" do
          result
          expect(document.reload.status).to eq("removed")
        end
      end
    end

    describe "a scan that runs out of budget" do
      before do
        write("one.md")
        write("two.md")
        stub_const("#{described_class}::BUDGET", 0.seconds)
      end

      context "with a source that cannot resume where it left off" do
        it "is never interrupted, however long it takes" do
          expect(result.status).to eq("completed")
        end

        it "reports every item" do
          expect(result.found_count).to eq(2)
        end
      end

      context "with a source that can resume" do
        before { make_resumable(%w[one.md two.md]) }

        it "pauses the run rather than completing it" do
          expect(result.status).to eq("paused")
        end

        it "stops after the item that exhausted the budget" do
          expect(result.found_count).to eq(1)
        end

        it "leaves finished_at unset" do
          expect(result.finished_at).to be_nil
        end

        it "records the counts it got to" do
          expect(result.created_count).to eq(1)
        end

        it "does not stamp last_synced_at, which would idle the source mid-scan" do
          result
          expect(source.reload.last_synced_at).to be_nil
        end

        it "tombstones nothing — it has only seen part of the source" do
          create(:document, source: source, external_id: "vanished.md", status: "processed")
          expect(result.removed_count).to eq(0)
        end

        it "leaves a document it has not reached yet alone" do
          document = create(:document, source: source, external_id: "vanished.md", status: "processed")
          result
          expect(document.reload.status).to eq("processed")
        end
      end
    end

    # The window the sweeper cannot see: a pass wedged inside #each_item reports
    # no progress, gets retired as stalled, and wakes to find its source already
    # due again and its semaphore expired — so a second pass may be underway.
    describe "a scan that is retired while it is still working" do
      before do
        write("one.md")
        write("two.md")

        # Heartbeat on every item, so the retirement is noticed on the next one.
        stub_const("#{described_class}::PROGRESS_INTERVAL", 0.seconds)

        # Stand in for the sweeper: retire the run the moment it is created.
        allow(source.syncs).to receive(:create!).and_wrap_original do |original, *args|
          original.call(*args).tap { |run| run.update!(status: "failed", finished_at: Time.current) }
        end
      end

      it "stands down rather than finishing the run" do
        expect(result.status).to eq("failed")
      end

      it "leaves the sweeper's verdict alone rather than writing its own counts" do
        expect(result.found_count).to eq(0)
      end

      it "does not stamp last_synced_at" do
        result
        expect(source.reload.last_synced_at).to be_nil
      end

      it "tombstones nothing — a second pass may be reconciling the same source" do
        document = create(:document, source: source, external_id: "vanished.md", status: "processed")
        result
        expect(document.reload.status).to eq("processed")
      end

      it "stops writing documents immediately" do
        expect { result }.not_to change { source.documents.count }
      end
    end

    describe "resuming a paused scan" do
      subject(:resumed) { described_class.new(source.reload).call }

      let!(:first_pass) do
        make_resumable(%w[one.md two.md])
        stub_const("#{described_class}::BUDGET", 0.seconds)
        sync.call
      end

      before { stub_const("#{described_class}::BUDGET", 15.minutes) }

      it "picks up the paused run instead of opening a new one" do
        expect(resumed).to eq(first_pass)
      end

      it "leaves the source with exactly one run" do
        resumed
        expect(source.syncs.count).to eq(1)
      end

      it "completes it once the source runs out of items" do
        expect(resumed.status).to eq("completed")
      end

      it "accumulates counts across both passes rather than reporting the last one" do
        expect(resumed.found_count).to eq(2)
      end

      it "stamps last_synced_at now that the scan is over" do
        resumed
        expect(source.reload.last_synced_at).to be_present
      end

      it "tombstones what the completed pass never saw" do
        document = create(:document, source: source, external_id: "vanished.md", status: "processed")
        resumed
        expect(document.reload.status).to eq("removed")
      end

      # The documents the first pass stamped are stamped with this same run, so
      # resuming must not read them as vanished.
      it "keeps the documents the earlier pass reconciled" do
        resumed
        expect(source.documents.where(status: "removed")).to be_empty
      end
    end

    context "when the folder cannot be read at all" do
      before do
        allow(source).to receive(:each_item).and_raise(Errno::ENOENT, "no such directory")
      end

      it "re-raises so the job records a failure" do
        expect { result }.to raise_error(Errno::ENOENT)
      end

      it "marks the run failed" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(source.syncs.sole.status).to eq("failed")
      end

      it "records the error" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(source.syncs.sole.error).to include("Errno::ENOENT")
      end

      it "still stamps last_synced_at so the scheduler waits out the interval" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(source.reload.last_synced_at).to be_present
      end
    end
  end
end
