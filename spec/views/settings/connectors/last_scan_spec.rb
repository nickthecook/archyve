require "rails_helper"

RSpec.describe Views::Settings::Connectors::LastScan do
  subject(:component) { described_class.new(connector: connector) }

  let(:connector) { create(:folder_connector, path: root) }
  let(:root) { Dir.mktmpdir("archyve-last-scan-spec") }
  let(:result) { component.call }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  # The whole point of keeping this component helper-free: a model renders it to
  # a string from a job, where there is no view context for phlex-rails helpers
  # to reach for. If this ever starts raising, a broadcast has been broken.
  describe "#call outside a request" do
    context "with a completed scan" do
      before do
        connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current,
          status: "completed", found_count: 2)
      end

      it "renders without a view context" do
        expect(result).to include("completed in")
      end

      it "renders the relative time, which needs a Rails date helper" do
        expect(result).to include("started 1 minute ago")
      end
    end
  end

  describe "the broadcast target" do
    context "with no scans yet" do
      it "still renders the region, so the target exists before the first run" do
        expect(result).to include(described_class.dom_id(connector))
      end

      it "says the connector has not been scanned" do
        expect(result).to include("Not scanned yet")
      end
    end
  end

  describe "polling" do
    context "with a scan still running" do
      before { connector.syncs.create!(started_at: Time.current, status: "running") }

      it "keeps polling" do
        expect(result).to include('progress-terminal-value="false"')
      end
    end

    context "with a finished scan whose documents are still processing" do
      before do
        sync = connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
        create(:document, connector: connector, connector_sync: sync, status: "pending")
      end

      it "keeps polling" do
        expect(result).to include('progress-terminal-value="false"')
      end
    end

    context "with a finished scan whose documents are all done" do
      before do
        sync = connector.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
        create(:document, connector: connector, connector_sync: sync, status: "processed")
      end

      it "stops polling" do
        expect(result).to include('progress-terminal-value="true"')
      end
    end

    context "with a run that never reported back" do
      before { connector.syncs.create!(started_at: 3.hours.ago, status: "running") }

      it "stops polling, since a stalled run will not move on its own" do
        expect(result).to include('progress-terminal-value="true"')
      end
    end
  end
end
