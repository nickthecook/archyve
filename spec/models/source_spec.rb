require "rails_helper"

RSpec.describe Source do
  # Manual upload files documents one at a time, chosen as you upload. A
  # standing feed would mean every future upload by that person silently joined
  # the collection.
  describe "#update_fed_collections" do
    subject(:source) { create(:manual_upload_source) }

    let(:collection) { create(:collection) }

    context "when a manual upload source is asked to feed a collection" do
      it "refuses" do
        expect { source.update_fed_collections([collection]) }
          .to raise_error(Source::CannotFeedCollectionsError)
      end
    end

    # Called unconditionally on save in some paths; an empty list is a no-op,
    # not an attempt to feed anything.
    context "when it is asked to feed nothing" do
      it "is allowed" do
        expect { source.update_fed_collections([]) }.not_to raise_error
      end
    end
  end

  describe ".attachable_by" do
    subject(:result) { described_class.attachable_by(user) }

    let(:user) { create(:user, :admin) }
    let!(:folder) { create(:folder_source) }
    let!(:uploads) { create(:manual_upload_source) }

    it "offers a folder source" do
      expect(result).to include(folder)
    end

    it "does not offer a manual upload source, even to an admin" do
      expect(result).not_to include(uploads)
    end
  end

  # Ownership is a grant. A per-user upload source has a user_id and no
  # source_users row, and its owner still administers it.
  describe "#granted_role_for" do
    subject(:source) { create(:source, user: owner) }

    let(:owner) { create(:user, :operator) }
    let(:result) { source.granted_role_for(person) }

    context "when asked about the owner" do
      let(:person) { owner }

      it "is admin, with no grant row needed" do
        expect(result).to eq("admin")
      end
    end

    context "when asked about someone with an explicit grant" do
      let(:person) { create(:user, :operator) }

      before { create(:source_user, source:, user: person) }

      it "is that grant" do
        expect(result).to eq("operator")
      end
    end

    context "when asked about someone with neither" do
      let(:person) { create(:user, :operator) }

      it "is nil, meaning no access" do
        expect(result).to be_nil
      end
    end
  end

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
