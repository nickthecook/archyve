require "rails_helper"

RSpec.describe Crawl::Robots do
  subject(:robots) { described_class.parse(text, agent: "Archyve/2 (+https://example.com)") }

  let(:text) { "" }

  describe "#allowed?" do
    context "with no robots.txt at all" do
      it { expect(robots.allowed?("/anything")) .to be(true) }
    end

    context "with a wildcard group disallowing a subtree" do
      let(:text) { "User-agent: *\nDisallow: /private\n" }

      it { expect(robots.allowed?("/private/notes")).to be(false) }
      it { expect(robots.allowed?("/docs/notes")).to be(true) }
    end

    # Longest-match-wins rather than first-match: a broad Disallow with narrow
    # Allow exceptions under it is how robots.txt is actually written, and
    # first-match reads that as "none of this".
    context "with an Allow carved out of a Disallow" do
      let(:text) { "User-agent: *\nDisallow: /docs\nAllow: /docs/public\n" }

      it { expect(robots.allowed?("/docs/internal")).to be(false) }
      it { expect(robots.allowed?("/docs/public/guide")).to be(true) }
    end

    context "with a wildcard inside the pattern" do
      let(:text) { "User-agent: *\nDisallow: /*.pdf\n" }

      it { expect(robots.allowed?("/docs/manual.pdf")).to be(false) }
      it { expect(robots.allowed?("/docs/manual.html")).to be(true) }
    end

    context "with an end-anchored pattern" do
      let(:text) { "User-agent: *\nDisallow: /search$\n" }

      it { expect(robots.allowed?("/search")).to be(false) }
      it { expect(robots.allowed?("/search/results")).to be(true) }
    end

    # A group naming us wins outright — the wildcard group's rules are not
    # merged in underneath it.
    context "with both a group naming us and a wildcard group" do
      let(:text) { "User-agent: *\nDisallow: /\n\nUser-agent: archyve\nDisallow: /private\n" }

      it { expect(robots.allowed?("/docs")).to be(true) }
      it { expect(robots.allowed?("/private")).to be(false) }
    end

    context "with comments and blank lines" do
      let(:text) { "# ours\nUser-agent: *   # everyone\n\nDisallow: /private\n" }

      it { expect(robots.allowed?("/private")).to be(false) }
    end

    context "with several agents sharing one set of rules" do
      let(:text) { "User-agent: archyve\nUser-agent: othercrawler\nDisallow: /private\n" }

      it { expect(robots.allowed?("/private")).to be(false) }
    end
  end

  describe "#crawl_delay" do
    context "with a delay in the group that applies to us" do
      let(:text) { "User-agent: *\nCrawl-delay: 2.5\n" }

      it { expect(robots.crawl_delay).to eq(2.5) }
    end

    context "with a delay only in a group that does not apply to us" do
      let(:text) { "User-agent: someone-else\nCrawl-delay: 30\n" }

      it { expect(robots.crawl_delay).to be_nil }
    end
  end

  describe "#sitemaps" do
    context "with sitemap lines outside any group" do
      let(:text) { "Sitemap: https://docs.test/sitemap.xml\nUser-agent: *\nDisallow:\n" }

      it { expect(robots.sitemaps).to eq(["https://docs.test/sitemap.xml"]) }
    end
  end
end
