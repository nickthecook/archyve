require "rails_helper"

RSpec.describe Sources::EnqueueDueSyncsJob do
  subject(:job) { described_class.new }

  let(:root) { Dir.mktmpdir("archyve-due-syncs-spec") }
  let(:result) { job.perform }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#perform" do
    context "with a source that is due" do
      let!(:source) { create(:folder_source, path: root, last_synced_at: nil) }

      it "enqueues a scan for it" do
        expect { result }.to have_enqueued_job(Sources::SyncJob).with(source)
      end
    end

    context "with a source synced more recently than its interval" do
      before { create(:folder_source, path: root, sync_interval_minutes: 60, last_synced_at: 1.minute.ago) }

      it "leaves it alone" do
        expect { result }.not_to have_enqueued_job(Sources::SyncJob)
      end
    end

    context "with only a manual upload source" do
      before { create(:manual_upload_source, last_synced_at: nil) }

      it "enqueues nothing" do
        expect { result }.not_to have_enqueued_job(Sources::SyncJob)
      end
    end

    context "with several due sources" do
      before do
        create(:folder_source, path: root, last_synced_at: nil)
        create(:folder_source, path: root, last_synced_at: nil)
      end

      it "enqueues one scan each" do
        expect { result }.to have_enqueued_job(Sources::SyncJob).twice
      end
    end
  end
end
