require "rails_helper"

RSpec.describe Crawl::Sitemap do
  subject(:result) { described_class.urls("https://docs.test/sitemap.xml", fetcher: fetcher, boundary: boundary) }

  let(:boundary) { Crawl::Boundary.new(origin: "https://docs.test", prefix: "/docs") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:fetcher) { Crawl::Fetcher.new(client: Faraday.new { |f| f.adapter(:test, stubs) }) }

  def stub_xml(url, body, headers: { "Content-Type" => "application/xml" })
    stubs.get(url) { [200, headers, body] }
  end

  describe ".urls" do
    context "with a plain urlset" do
      before do
        stub_xml("https://docs.test/sitemap.xml", <<~XML)
          <urlset><url><loc>https://docs.test/docs/a/</loc></url>
          <url><loc>https://docs.test/docs/b</loc></url></urlset>
        XML
      end

      # Canonicalised on the way out, so the frontier's unique index sees the
      # same spelling a link to the same page would produce.
      it { expect(result).to eq(["https://docs.test/docs/a", "https://docs.test/docs/b"]) }
    end

    context "with a sitemap index" do
      before do
        stub_xml("https://docs.test/sitemap.xml", <<~XML)
          <sitemapindex><sitemap><loc>https://docs.test/sitemap-1.xml</loc></sitemap></sitemapindex>
        XML
        stub_xml("https://docs.test/sitemap-1.xml", "<urlset><url><loc>https://docs.test/docs/a</loc></url></urlset>")
      end

      it { expect(result).to eq(["https://docs.test/docs/a"]) }
    end

    # Large sitemaps are conventionally gzipped, and by extension as often as by
    # content-type.
    context "with a gzipped sitemap" do
      subject(:result) { described_class.urls("https://docs.test/sitemap.xml.gz", fetcher: fetcher, boundary: boundary) }

      before do
        buffer = StringIO.new
        Zlib::GzipWriter.wrap(buffer) { |gz| gz.write("<urlset><url><loc>https://docs.test/docs/a</loc></url></urlset>") }
        stubs.get("https://docs.test/sitemap.xml.gz") { [200, { "Content-Type" => "application/gzip" }, buffer.string] }
      end

      it { expect(result).to eq(["https://docs.test/docs/a"]) }
    end

    context "with no sitemap at that address" do
      before { stubs.get("https://docs.test/sitemap.xml") { [404, {}, ""] } }

      it { expect(result).to eq([]) }
    end

    # Somebody else's XML, so it is not to be believed further than it parses.
    context "with a malformed sitemap" do
      before { stub_xml("https://docs.test/sitemap.xml", "<urlset><url><loc>not a url") }

      it { expect(result).to eq([]) }
    end
  end
end
