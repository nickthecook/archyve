require "rails_helper"

RSpec.describe Source do
  describe ".syncable_types" do
    it "includes sources that can be scanned" do
      expect(described_class.syncable_types).to include("Sources::Folder")
    end

    it "excludes manual upload, which has nothing to scan" do
      expect(described_class.syncable_types).not_to include("Sources::ManualUpload")
    end
  end

  describe ".creatable_types" do
    it "offers the folder source" do
      expect(described_class.creatable_types).to include(Sources::Folder)
    end

    it "excludes manual upload, which is created implicitly on first upload" do
      expect(described_class.creatable_types).not_to include(Sources::ManualUpload)
    end
  end

  describe "the sync contract" do
    context "with a subclass that has not implemented it" do
      subject(:source) { Sources::ManualUpload.new(name: "incomplete") }

      it "raises a StandardError from #each_item, so a sync run can record it" do
        expect { source.each_item }.to raise_error(described_class::MissingImplementationError)
      end

      it "raises a StandardError from #read" do
        expect { source.read("anything") }.to raise_error(described_class::MissingImplementationError)
      end

      it "is catchable by the engine's rescue, unlike NotImplementedError" do
        expect(described_class::MissingImplementationError.ancestors).to include(StandardError)
      end
    end
  end

  describe ".due_for_sync" do
    subject(:due) { described_class.due_for_sync }

    let(:root) { Dir.mktmpdir("archyve-due-spec") }

    after { FileUtils.remove_entry(root) if File.exist?(root) }

    context "with a source that has never synced" do
      let!(:source) { create(:folder_source, path: root, last_synced_at: nil) }

      it { expect(due).to include(source) }
    end

    context "with a source synced longer ago than its interval" do
      let!(:source) do
        create(:folder_source, path: root, sync_interval_minutes: 30, last_synced_at: 31.minutes.ago)
      end

      it { expect(due).to include(source) }
    end

    context "with a source synced more recently than its interval" do
      let!(:source) do
        create(:folder_source, path: root, sync_interval_minutes: 30, last_synced_at: 5.minutes.ago)
      end

      it { expect(due).not_to include(source) }
    end

    context "with a source that has no interval configured" do
      let!(:source) do
        create(:folder_source, path: root, sync_interval_minutes: nil,
          last_synced_at: (Sources::Folder::DEFAULT_SYNC_INTERVAL_MINUTES + 1).minutes.ago)
      end

      it "falls back to the default interval" do
        expect(due).to include(source)
      end
    end

    context "with a source that is already mid-sync" do
      let!(:source) { create(:folder_source, path: root, last_synced_at: nil) }

      before { source.syncs.create!(started_at: Time.current, status: "running") }

      it "leaves it out so ticks don't pile up behind a slow scan" do
        expect(due).not_to include(source)
      end
    end

    context "with a source whose previous sync finished" do
      let!(:source) { create(:folder_source, path: root, last_synced_at: nil) }

      before { source.syncs.create!(started_at: 1.hour.ago, finished_at: Time.current, status: "completed") }

      it { expect(due).to include(source) }
    end

    context "with a manual upload source" do
      let!(:source) { create(:manual_upload_source, last_synced_at: nil) }

      it "never includes it" do
        expect(due).not_to include(source)
      end
    end
  end
end
