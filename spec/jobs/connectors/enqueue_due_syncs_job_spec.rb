require "rails_helper"

RSpec.describe Connectors::EnqueueDueSyncsJob do
  subject(:job) { described_class.new }

  let(:root) { Dir.mktmpdir("archyve-due-syncs-spec") }
  let(:result) { job.perform }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#perform" do
    context "with a connector that is due" do
      let!(:connector) { create(:folder_connector, path: root, last_synced_at: nil) }

      it "enqueues a scan for it" do
        expect { result }.to have_enqueued_job(Connectors::SyncJob).with(connector)
      end
    end

    context "with a connector synced more recently than its interval" do
      before { create(:folder_connector, path: root, sync_interval_minutes: 60, last_synced_at: 1.minute.ago) }

      it "leaves it alone" do
        expect { result }.not_to have_enqueued_job(Connectors::SyncJob)
      end
    end

    context "with only a manual upload connector" do
      before { create(:manual_upload_connector, last_synced_at: nil) }

      it "enqueues nothing" do
        expect { result }.not_to have_enqueued_job(Connectors::SyncJob)
      end
    end

    context "with several due connectors" do
      before do
        create(:folder_connector, path: root, last_synced_at: nil)
        create(:folder_connector, path: root, last_synced_at: nil)
      end

      it "enqueues one scan each" do
        expect { result }.to have_enqueued_job(Connectors::SyncJob).twice
      end
    end
  end
end
