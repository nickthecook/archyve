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

      # Matched either side of the apostrophe, which Phlex escapes to &#39;.
      it { expect(result).to include("12 documents this scan") }
      it { expect(result).to include("reach were left alone") }

      it "says what caused it" do
        expect(result).to include("1 URL gave no answer")
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
        expect(result).to include("No answer in time")
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
