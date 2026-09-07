require "rails_helper"

RSpec.describe Connectors::Sync do
  subject(:sync) { described_class.new(connector) }

  let(:connector) { create(:folder_connector, path: root) }
  let(:root) { Dir.mktmpdir("archyve-sync-spec") }
  let(:result) { sync.call }

  def write(relative, content: "hello")
    absolute = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, content)
    absolute
  end

  # The version token the connector currently reports for a file, so a spec can
  # set up a document that is genuinely up to date.
  def current_version(relative)
    connector.each_item.find { |item| item.external_id == relative }.version
  end

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#call" do
    context "with a file the connector has never seen" do
      before { write("new.md") }

      it "creates a document for it" do
        expect { result }.to change { connector.documents.count }.from(0).to(1)
      end

      it "identifies the document by its path relative to the root" do
        result
        expect(connector.documents.sole.external_id).to eq("new.md")
      end

      it "counts it as created" do
        expect(result.created_count).to eq(1)
      end

      it "enqueues an import for it" do
        expect { result }.to have_enqueued_job(Connectors::ImportItemJob)
      end

      it "leaves source_version unset until the import succeeds" do
        result
        expect(connector.documents.sole.source_version).to be_nil
      end

      it "attributes the document to the run" do
        expect(connector.documents.sole.connector_sync).to eq(result) if result
      end
    end

    context "with a file already ingested at its current version" do
      before do
        write("stable.md")
        create(:document, connector: connector, external_id: "stable.md",
          source_version: current_version("stable.md"), status: "processed")
      end

      it "counts it as unchanged" do
        expect(result.unchanged_count).to eq(1)
      end

      it "does not enqueue an import" do
        expect { result }.not_to have_enqueued_job(Connectors::ImportItemJob)
      end
    end

    context "with a file whose version token has moved" do
      before do
        write("changed.md")
        create(:document, connector: connector, external_id: "changed.md",
          source_version: "stale-token", status: "processed")
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end

      it "enqueues an import for it" do
        expect { result }.to have_enqueued_job(Connectors::ImportItemJob)
      end

      it "keeps the old source_version until the import succeeds" do
        result
        expect(connector.documents.sole.source_version).to eq("stale-token")
      end
    end

    context "with a document whose file is gone from the folder" do
      let!(:document) do
        create(:document, connector: connector, external_id: "deleted.md",
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
        create(:document, connector: connector, external_id: "broken.md",
          source_version: current_version("broken.md"), status: "failed")
      end

      it "re-imports it even though the version token is unchanged" do
        expect { result }.to have_enqueued_job(Connectors::ImportItemJob)
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end
    end

    context "with a file the connector reports but declines to ingest" do
      let(:oversized) do
        Connector::Item.new(
          external_id: "huge.pdf", version: "v1", title: "huge.pdf",
          content_type: "application/pdf", skip_reason: "too big"
        )
      end

      before { allow(connector).to receive(:each_item) { |&block| block.call(oversized) } }

      it "counts it as skipped" do
        expect(result.skipped_count).to eq(1)
      end

      it "does not import it" do
        expect { result }.not_to have_enqueued_job(Connectors::ImportItemJob)
      end

      it "does not create a document for it" do
        expect { result }.not_to change { connector.documents.count }
      end
    end

    context "when a document's file is still there but has grown too large to ingest" do
      let(:oversized) do
        Connector::Item.new(
          external_id: "grew.md", version: "v2", title: "grew.md",
          content_type: "text/markdown", skip_reason: "too big"
        )
      end
      let!(:document) do
        create(:document, connector: connector, external_id: "grew.md", source_version: "v1", status: "processed")
      end

      before { allow(connector).to receive(:each_item) { |&block| block.call(oversized) } }

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
        Connector::Item.new(
          external_id: "frozen.md", version: "v1", title: "frozen.md",
          content_type: "text/markdown", skip_reason: "too big"
        )
      end

      before do
        create(:document, connector: connector, external_id: "frozen.md", source_version: "v1", status: "processed")
        allow(connector).to receive(:each_item) { |&block| block.call(oversized) }
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
        create(:document, connector: connector, external_id: "big.md", source_version: "v1", status: "processed")
      end

      before do
        write("big.md", content: "now within the limit")
        allow(connector).to receive(:each_item).and_call_original
      end

      it "re-imports it" do
        expect { result }.to have_enqueued_job(Connectors::ImportItemJob)
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end
    end

    context "with a tombstoned document whose file has come back" do
      before do
        write("restored.md")
        create(:document, connector: connector, external_id: "restored.md",
          source_version: current_version("restored.md"), status: "removed")
      end

      it "re-imports it even though the version token is unchanged" do
        expect { result }.to have_enqueued_job(Connectors::ImportItemJob)
      end

      it "counts it as updated" do
        expect(result.updated_count).to eq(1)
      end
    end

    context "when a removed document was fed into a collection by this connector" do
      let(:collection) { create(:collection) }
      let(:document) do
        create(:document, connector: connector, external_id: "gone.md", status: "processed")
      end

      before { CollectionMembership.feed!(document: document, collection: collection) }

      it "retracts the connector's membership" do
        result
        expect(CollectionMembership.find_by(document: document, collection: collection)).not_to be_active
      end
    end

    context "when a removed document was filed into a collection by a person" do
      let(:collection) { create(:collection) }
      let(:document) do
        create(:document, connector: connector, external_id: "gone.md", status: "processed")
      end

      before { CollectionMembership.add(document: document, collection: collection) }

      it "leaves the manual membership alone" do
        result
        expect(CollectionMembership.find_by(document: document, collection: collection)).to be_active
      end
    end

    context "when one item fails and others are fine" do
      # An item the connector reports but that cannot become a Document — here
      # because it carries no external_id, the one thing every connector must
      # supply. Reconciling it raises, which is the case this context is about.
      let(:broken) do
        Connector::Item.new(external_id: "", version: "v1", title: "broken", content_type: "text/plain")
      end

      before do
        write("good.md")
        good = connector.each_item.to_a
        allow(connector).to receive(:each_item) do |&block|
          good.each(&block)
          block.call(broken)
        end
      end

      it "still creates the healthy document" do
        result
        expect(connector.documents.pluck(:external_id)).to eq(["good.md"])
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

      it "stamps the connector's last_synced_at" do
        expect { result }.to change { connector.reload.last_synced_at }.from(nil)
      end
    end

    context "when the folder cannot be read at all" do
      before do
        allow(connector).to receive(:each_item).and_raise(Errno::ENOENT, "no such directory")
      end

      it "re-raises so the job records a failure" do
        expect { result }.to raise_error(Errno::ENOENT)
      end

      it "marks the run failed" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(connector.syncs.sole.status).to eq("failed")
      end

      it "records the error" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(connector.syncs.sole.error).to include("Errno::ENOENT")
      end

      it "still stamps last_synced_at so the scheduler waits out the interval" do
        expect { result }.to raise_error(Errno::ENOENT)
        expect(connector.reload.last_synced_at).to be_present
      end
    end
  end
end
