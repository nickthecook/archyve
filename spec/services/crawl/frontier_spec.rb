require "rails_helper"

RSpec.describe Crawl::Frontier do
  subject(:frontier) { described_class.new(run, max_pages: max_pages, max_depth: max_depth) }

  let(:source) { create(:web_source) }
  let(:run) { create(:source_sync, source: source) }
  let(:max_pages) { 100 }
  let(:max_depth) { 5 }

  def resolve_all(disposition)
    frontier.take(100).each { |item| frontier.resolve(item, disposition: disposition, status_code: 200) }
  end

  describe "#discover" do
    let(:result) { frontier.discover(["https://docs.test/a", "https://docs.test/b"], depth: 1) }

    it { expect(result).to eq(2) }

    it "records the depth it was found at" do
      result
      expect(run.items.order(:id).first.detail).to eq("depth" => 1)
    end

    # Dedup is the unique index rather than a check-then-act, so rediscovering a
    # page — from another link, or on a later pass — is absorbed rather than
    # raising or queueing the page twice.
    context "with a URL the run already knows" do
      before { frontier.discover(["https://docs.test/a"], depth: 0) }

      it { expect(result).to eq(1) }
      it { expect { result }.to change(run.items, :count).by(1) }
    end

    context "with a URL already resolved on an earlier pass" do
      before do
        frontier.discover(["https://docs.test/a"], depth: 0)
        resolve_all(:ok)
      end

      it "does not queue it again" do
        result
        expect(run.items.pending.pluck(:external_id)).to eq(["https://docs.test/b"])
      end
    end

    context "with a depth past the limit" do
      let(:max_depth) { 1 }
      let(:result) { frontier.discover(["https://docs.test/deep"], depth: 2) }

      it { expect(result).to eq(0) }
    end
  end

  describe "#drained?" do
    before { frontier.discover(["https://docs.test/a"], depth: 0) }

    context "with a pending row" do
      it { expect(frontier).not_to be_drained }
    end

    context "with every row resolved" do
      before { resolve_all(:ok) }

      it { expect(frontier).to be_drained }
    end
  end

  describe "#exhausted?" do
    let(:max_pages) { 2 }

    before { frontier.discover(["https://docs.test/a", "https://docs.test/b"], depth: 0) }

    context "with the page budget unspent" do
      it { expect(frontier).not_to be_exhausted }
    end

    context "with the page budget spent" do
      before { resolve_all(:ok) }

      it { expect(frontier).to be_exhausted }
    end
  end

  describe "#authoritative?" do
    before { frontier.discover(urls, depth: 0) }

    let(:urls) { (1..10).map { |n| "https://docs.test/#{n}" } }

    context "with the frontier still holding work" do
      it { expect(frontier).not_to be_authoritative }
    end

    context "with every page answered cleanly" do
      before { resolve_all(:ok) }

      it { expect(frontier).to be_authoritative }
    end

    # Draining is not enough on its own: a frontier empties just as neatly when
    # part of the site timed out, and tombstoning on that would gut the archive
    # over a bad afternoon on the network.
    context "with some of the pages unanswered" do
      before do
        frontier.take(100).each_with_index do |item, index|
          frontier.resolve(item, disposition: index < 3 ? :timeout : :ok)
        end
      end

      it { expect(frontier).not_to be_authoritative }
    end

    # No tolerance, deliberately. The pages at risk are the ones *missing* from
    # the frontier, so they are absent from any ratio computed over it — a hub
    # failing among ninety-nine good pages would sail under any threshold while
    # hiding everything behind it.
    context "with a single page unanswered out of many" do
      let(:urls) { (1..100).map { |n| "https://docs.test/#{n}" } }

      before do
        frontier.take(200).each_with_index do |item, index|
          frontier.resolve(item, disposition: index.zero? ? :timeout : :ok)
        end
      end

      it { expect(frontier).not_to be_authoritative }
    end

    # A 404 is an answer, so it conceals nothing and leaves the run able to read
    # absence as deletion.
    context "with a page the site says is gone" do
      before do
        frontier.take(100).each_with_index do |item, index|
          frontier.resolve(item, disposition: index.zero? ? :not_found : :ok, status_code: 404)
        end
      end

      it { expect(frontier).to be_authoritative }
    end

    # A crawl stopped by its allowance leaves rows pending, which is the same
    # thing as not having drained — there is no separate check for it.
    context "with the crawl stopped by its page budget" do
      let(:max_pages) { 4 }

      before { frontier.take(4).each { |item| frontier.resolve(item, disposition: :ok) } }

      it { expect(frontier).to be_exhausted }
      it { expect(frontier).not_to be_authoritative }
    end

    context "with nothing crawled at all" do
      let(:urls) { [] }

      it { expect(frontier).not_to be_authoritative }
    end
  end

  describe "#take" do
    before do
      frontier.discover(["https://docs.test/a", "https://docs.test/b", "https://docs.test/c"], depth: 0)
    end

    it "hands back pending rows oldest first" do
      expect(frontier.take(2).map(&:external_id)).to eq(["https://docs.test/a", "https://docs.test/b"])
    end

    context "with the first row resolved" do
      before { frontier.resolve(frontier.take(1).first, disposition: :ok) }

      it { expect(frontier.take(1).map(&:external_id)).to eq(["https://docs.test/b"]) }
    end
  end
end
