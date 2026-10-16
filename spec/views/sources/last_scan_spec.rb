require "rails_helper"

RSpec.describe Views::Sources::LastScan do
  subject(:component) { described_class.new(source: source) }

  let(:source) { create(:folder_source, path: root) }
  let(:root) { Dir.mktmpdir("archyve-last-scan-spec") }
  let(:result) { component.call }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  # The whole point of keeping this component helper-free: a model renders it to
  # a string from a job, where there is no view context for phlex-rails helpers
  # to reach for. If this ever starts raising, a broadcast has been broken.
  describe "#call outside a request" do
    context "with a completed scan" do
      before do
        source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current,
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

  describe "how long the scan took" do
    context "with a scan measured in days" do
      before do
        source.syncs.create!(started_at: 101_638.seconds.ago, finished_at: Time.current, status: "completed")
      end

      it "rounds the headline off" do
        expect(result).to include("completed in")
        expect(result).to include("1 day")
      end

      it "puts the exact figure on hover" do
        expect(result).to include("1 day, 4 hours, 13 minutes, and 58 seconds")
      end
    end
  end

  # The bar is full and the scan is over; calling that "Processing" reads as a
  # pipeline that never finished.
  describe "the processing heading" do
    let(:sync) do
      source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
    end

    context "with documents still in the pipeline" do
      before { create(:document, source: source, source_sync: sync, status: "pending") }

      it { expect(result).to include(">Processing<") }
    end

    context "with every document done" do
      before { create(:document, source: source, source_sync: sync, status: "processed") }

      it { expect(result).to include(">Processed<") }
    end
  end

  # Whether the region keeps polling. A finished scan is the end of the story
  # unless another has just been asked for, in which case the run it is waiting
  # for doesn't exist yet and no broadcast will reach this page announcing it.
  describe "watching for a scan that hasn't started" do
    let(:previous) do
      source.syncs.create!(started_at: 2.minutes.ago, finished_at: 1.minute.ago, status: "completed")
    end

    context "with a finished scan and nothing asked for since" do
      before { previous }

      it { expect(result).to include('data-progress-terminal-value="true"') }
    end

    context "with a finished scan and a fresh request" do
      before do
        previous
        source.request_sync!
      end

      it { expect(result).to include('data-progress-terminal-value="false"') }
    end

    context "with a request and no scan ever" do
      before { source.request_sync! }

      it { expect(result).to include('data-progress-terminal-value="false"') }

      it "says what it is waiting for" do
        expect(result).to include("waiting for a worker")
      end
    end
  end

  # A source that has quietly stopped pruning has to say so on its own page —
  # one permanently broken URL means it never gets a clean run again.
  describe "the withheld note" do
    context "with a scan that removed what it could" do
      before { source.syncs.create!(started_at: Time.current, status: "completed", removed_count: 2) }

      it { expect(result).not_to include("left alone") }
    end

    context "with a scan that could not account for some documents" do
      before do
        sync = source.syncs.create!(started_at: Time.current, status: "completed", withheld_count: 12)
        sync.items.create!(external_id: "https://site/slow", disposition: "timeout")
      end

      it { expect(result).to include("12 documents left alone") }

      it "says what caused it" do
        expect(result).to include("1 URL gave no answer")
      end

      it "keeps the explanation to hover text" do
        expect(result).to include(described_class::WITHHELD_HINT)
      end
    end
  end

  # `found` and URLs visited differ, always, and people will ask why — so the
  # crawl block only appears for a source that produced one.
  describe "the crawl block" do
    context "with a scan that recorded no response stats" do
      before { source.syncs.create!(started_at: Time.current, status: "completed", found_count: 2) }

      it { expect(result).not_to include("URLs visited") }
    end

    context "with a scan that crawled" do
      before do
        source.syncs.create!(started_at: Time.current, status: "completed", found_count: 2,
          response_stats: { "200" => 12, "404" => 3, "timeout" => 1 })
      end

      it { expect(result).to include("16 URLs visited") }
      it { expect(result).to include("200 12") }

      it "explains what never reached HTTP at all" do
        expect(result).to include("Pages that gave no answer in time")
      end
    end
  end

  describe "the broadcast target" do
    context "with no scans yet" do
      it "still renders the region, so the target exists before the first run" do
        expect(result).to include(described_class.dom_id(source))
      end

      it "says the source has not been scanned" do
        expect(result).to include("Not scanned yet")
      end
    end
  end

  describe "polling" do
    context "with a scan still running" do
      before { source.syncs.create!(started_at: Time.current, status: "running") }

      it "keeps polling" do
        expect(result).to include('progress-terminal-value="false"')
      end
    end

    context "with a finished scan whose documents are still processing" do
      before do
        sync = source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
        create(:document, source: source, source_sync: sync, status: "pending")
      end

      it "keeps polling" do
        expect(result).to include('progress-terminal-value="false"')
      end
    end

    context "with a finished scan whose documents are all done" do
      before do
        sync = source.syncs.create!(started_at: 1.minute.ago, finished_at: Time.current, status: "completed")
        create(:document, source: source, source_sync: sync, status: "processed")
      end

      it "stops polling" do
        expect(result).to include('progress-terminal-value="true"')
      end
    end

    context "with a run that never reported back" do
      before { source.syncs.create!(started_at: 3.hours.ago, status: "running") }

      it "stops polling, since a stalled run will not move on its own" do
        expect(result).to include('progress-terminal-value="true"')
      end
    end
  end
end
