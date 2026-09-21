require "rails_helper"

RSpec.describe Sources::Web do
  subject(:source) { create(:web_source, endpoint: endpoint, path_prefix: "/docs") }

  let(:endpoint) { create(:web_endpoint, base_url: "https://docs.test") }
  let(:run) { create(:source_sync, source: source) }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  # A page with enough prose to clear Crawl::Page::MINIMUM_TEXT, so that
  # "nothing readable" stays a thing a spec has to ask for.
  def page_html(title, links: [], prose: "Everything you need to know about this, at some length. ")
    nav = links.map { |href| %(<a href="#{href}">#{href}</a>) }.join
    <<~HTML
      <html><head><title>#{title}</title></head>
      <body><nav>#{nav}</nav><main><h1>#{title}</h1><p>#{prose * 6}</p></main></body></html>
    HTML
  end

  def stub_page(path, body, status: 200, headers: { "Content-Type" => "text/html" })
    stubs.get(path) { [status, headers, body] }
  end

  # Registered before anything a context adds, because Faraday's test adapter
  # answers with the first stub that matches. Both are `let`s so a context can
  # change what the site says rather than stack a second stub behind the default.
  let(:robots_txt) { "User-agent: *\nDisallow: /docs/private\n" }
  let(:sitemap) { [404, {}, ""] }

  before do
    # On the association's own object, not on the source: overriding #endpoint
    # would defeat the contexts that hand the source the wrong kind of endpoint.
    allow(source.endpoint).to receive(:client).and_return(Faraday.new { |f| f.adapter(:test, stubs) })

    stub_page("/robots.txt", robots_txt, headers: { "Content-Type" => "text/plain" })
    stubs.get("https://docs.test/sitemap.xml") { sitemap }
  end

  describe "validations" do
    context "with a Web endpoint and a path" do
      it { expect(source).to be_valid }
    end

    context "with a full address as the path prefix" do
      subject(:source) { build(:web_source, path_prefix: "https://docs.test/docs") }

      it "rejects it" do
        source.valid?
        expect(source.errors[:path_prefix]).to include(a_string_including("must be a path"))
      end
    end

    context "with a full address as the start path" do
      subject(:source) { build(:web_source, start_path: "https://docs.test/index") }

      it "rejects it" do
        source.valid?
        expect(source.errors[:start_path]).to include(a_string_including("must be a path"))
      end
    end

    # The endpoint's path is an admin's limit on what an operator may reach with
    # its credentials, so the source's paths have to sit inside it.
    context "with an endpoint confined to part of the site" do
      let(:endpoint) { create(:web_endpoint, base_url: "https://docs.test", path_prefix: "/wiki") }

      context "with a path under the endpoint's" do
        subject(:source) { build(:web_source, endpoint: endpoint, path_prefix: "/wiki/docs") }

        it { expect(source).to be_valid }
      end

      context "with a path outside the endpoint's" do
        subject(:source) { build(:web_source, endpoint: endpoint, path_prefix: "/elsewhere") }

        it "rejects it" do
          source.valid?
          expect(source.errors[:path_prefix]).to include(a_string_including("must be under /wiki"))
        end
      end

      # The one that is easy to miss: a start page is *meant* to sit outside the
      # source's own path, so only the endpoint's limit stops it being a way to
      # reach the rest of the host.
      context "with a start page outside the endpoint's path" do
        subject(:source) do
          build(:web_source, endpoint: endpoint, path_prefix: "/wiki/docs", start_path: "/index")
        end

        it "rejects it" do
          source.valid?
          expect(source.errors[:start_path]).to include(a_string_including("must be under /wiki"))
        end
      end
    end

    context "with an endpoint of another type" do
      subject(:source) { build(:web_source, endpoint: create(:bookstack_endpoint)) }

      it "rejects it" do
        source.valid?
        expect(source.errors[:endpoint]).to include(a_string_including("Website"))
      end
    end
  end

  describe "#each_item" do
    let(:result) { source.each_item(run).to_a }

    context "with a seed page linking to two more" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a", "/docs/b"]))
        stub_page("https://docs.test/docs/a", page_html("A"))
        stub_page("https://docs.test/docs/b", page_html("B"))
      end

      it { expect(result.map(&:title)).to contain_exactly("Index", "A", "B") }
      it { expect(result.map(&:external_id)).to all(start_with("https://docs.test/docs")) }

      it "identifies each page by its canonical URL" do
        expect(result.map(&:external_id)).to include("https://docs.test/docs/a")
      end

      it "versions on the extracted content rather than the response body" do
        expect(result.map(&:version).uniq.size).to eq(3)
      end

      it "leaves the frontier drained" do
        result
        expect(run.items.pending).to be_empty
      end

      it "records how each URL resolved" do
        result
        expect(run.items.pluck(:disposition).uniq).to eq(["ok"])
      end
    end

    # The link is on the page, and it is not ours. Following it is how a crawl
    # of one site turns into a crawl of the web.
    context "with a link to another host" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["https://elsewhere.test/docs/x"]))
      end

      it { expect(result.map(&:external_id)).to eq(["https://docs.test/docs"]) }
    end

    context "with a link outside the path prefix" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/blog/post", "/docsearch"]))
      end

      it "follows neither the other subtree nor the lookalike path" do
        expect(result.map(&:external_id)).to eq(["https://docs.test/docs"])
      end
    end

    context "with the same page linked from two others" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a", "/docs/b"]))
        stub_page("https://docs.test/docs/a", page_html("A", links: ["/docs/shared"]))
        stub_page("https://docs.test/docs/b", page_html("B", links: ["/docs/shared"]))
        stub_page("https://docs.test/docs/shared", page_html("Shared"))
      end

      it "fetches it once" do
        expect(result.map(&:title).tally["Shared"]).to eq(1)
      end
    end

    context "with a page that links back to the one that found it" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a"]))
        stub_page("https://docs.test/docs/a", page_html("A", links: ["/docs"]))
      end

      it { expect(result.map(&:title)).to contain_exactly("Index", "A") }
    end

    # Pins the agent token end to end: if the name the crawl sends stopped
    # matching the name robots.txt is parsed against, the wildcard group would
    # apply instead and nothing at all would be crawled.
    context "with robots.txt naming Archyve specifically" do
      let(:robots_txt) { "User-agent: *\nDisallow: /\n\nUser-agent: archyve\nDisallow: /docs/private\n" }

      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a", "/docs/private"]))
        stub_page("https://docs.test/docs/a", page_html("A"))
      end

      it { expect(result.map(&:title)).to contain_exactly("Index", "A") }
    end

    context "with a page robots.txt disallows" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/private"]))
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }

      it "records why it was passed over" do
        result
        expect(run.items.find_by(external_id: "https://docs.test/docs/private").disposition)
          .to eq("robots_excluded")
      end
    end

    context "with a page marked noindex" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/draft"]))
        stub_page(
          "https://docs.test/docs/draft",
          page_html("Draft").sub("<head>", '<head><meta name="robots" content="noindex">')
        )
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }

      it "records why it was passed over" do
        result
        expect(run.items.nothing_readable.count).to eq(1)
      end
    end

    # A client-rendered page parses fine and extracts to nothing. Storing it
    # would mean a document that nothing retrieves and nothing explains.
    context "with a page that extracts to almost nothing" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/spa"]))
        stub_page("https://docs.test/docs/spa", '<html><head><title>App</title></head><body><div id="root"></div></body></html>')
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }

      it "says so rather than storing an empty document" do
        result
        item = run.items.find_by(external_id: "https://docs.test/docs/spa")
        expect(item.detail["reason"]).to eq("no text extracted")
      end
    end

    context "with a page that is not HTML" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/manual.pdf"]))
        stub_page("https://docs.test/docs/manual.pdf", "%PDF-1.4", headers: { "Content-Type" => "application/pdf" })
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }
    end

    context "with a dead link" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/gone"]))
        stub_page("https://docs.test/docs/gone", "", status: 404)
      end

      # A URL that was never a document is a fact about the crawl, not about
      # the archive — so it lands here and nowhere else.
      it "records it without producing a document" do
        result
        item = run.items.find_by(external_id: "https://docs.test/docs/gone")
        expect([item.disposition, item.status_code]).to eq(["not_found", 404])
      end
    end

    context "with a page the site refuses" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/secret"]))
        stub_page("https://docs.test/docs/secret", "", status: 403)
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }

      it "records the refusal" do
        result
        item = run.items.find_by(external_id: "https://docs.test/docs/secret")
        expect([item.disposition, item.status_code]).to eq(["forbidden", 403])
      end

      # A refusal is a definite answer, so it does not drag the crawl below
      # authoritative the way a timeout would.
      it "stays authoritative" do
        result
        expect(source.authoritative_scan?(run)).to be(true)
      end
    end

    context "with a redirect to another page in scope" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/old"]))
        stub_page("https://docs.test/docs/old", "", status: 301,
          headers: { "Location" => "https://docs.test/docs/new" })
        stub_page("https://docs.test/docs/new", page_html("New"))
      end

      it { expect(result.map(&:title)).to contain_exactly("Index", "New") }

      it "resolves the redirecting URL rather than turning it into a document" do
        result
        expect(run.items.find_by(external_id: "https://docs.test/docs/old").disposition).to eq("redirected")
      end
    end

    context "with a redirect out of scope" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/away"]))
        stub_page("https://docs.test/docs/away", "", status: 302,
          headers: { "Location" => "https://elsewhere.test/landing" })
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }

      it "does not queue the target" do
        result
        expect(run.items.count).to eq(2)
      end
    end

    # A site that canonicalises to a trailing slash redirects our slash-less
    # canonical URL back to itself. Read as an ordinary redirect that is a dead
    # end: the target canonicalises to the row we just resolved.
    context "with a site that redirects to the trailing-slash spelling" do
      before do
        stubs.get("https://docs.test/docs") { [301, { "Location" => "https://docs.test/docs/" }, ""] }
        stubs.get("https://docs.test/docs/") { [200, { "Content-Type" => "text/html" }, page_html("Index")] }
      end

      it { expect(result.map(&:title)).to eq(["Index"]) }
      it { expect(result.map(&:external_id)).to eq(["https://docs.test/docs"]) }
    end

    context "with a sitemap listing pages nothing links to" do
      let(:sitemap) do
        [200, { "Content-Type" => "application/xml" }, <<~XML]
          <urlset><url><loc>https://docs.test/docs</loc></url>
          <url><loc>https://docs.test/docs/orphan</loc></url>
          <url><loc>https://elsewhere.test/docs/other</loc></url></urlset>
        XML
      end

      before do
        stub_page("https://docs.test/docs", page_html("Index"))
        stub_page("https://docs.test/docs/orphan", page_html("Orphan"))
      end

      it { expect(result.map(&:title)).to contain_exactly("Index", "Orphan") }
    end

    # A wiki category, a changelog, an index: each links to content living
    # elsewhere on the site, so bounding a crawl by the page it starts at finds
    # exactly one page.
    context "with a start page that links outside its own path" do
      subject(:source) do
        create(:web_source, endpoint: endpoint, path_prefix: "/", start_path: "/Category:Lore")
      end

      before do
        stub_page("https://docs.test/Category:Lore", page_html("Lore", links: ["/Marathon", "/Pfhor"]))
        stub_page("https://docs.test/Marathon", page_html("Marathon"))
        stub_page("https://docs.test/Pfhor", page_html("Pfhor"))
      end

      it { expect(result.map(&:title)).to contain_exactly("Lore", "Marathon", "Pfhor") }
    end

    context "with a start page outside the path it feeds" do
      subject(:source) do
        create(:web_source, endpoint: endpoint, path_prefix: "/docs", start_path: "/index")
      end

      before do
        stub_page("https://docs.test/index", page_html("Index", links: ["/docs/a"]))
        stub_page("https://docs.test/docs/a", page_html("A"))
      end

      # Fetched for its links, which is the whole point of naming it — but the
      # archive was asked for /docs, so it is not a document.
      it { expect(result.map(&:title)).to eq(["A"]) }

      it "records why it produced nothing" do
        result
        expect(run.items.find_by(external_id: "https://docs.test/index").disposition).to eq("out_of_scope")
      end
    end

    context "with a start page named and a sitemap available" do
      subject(:source) do
        create(:web_source, endpoint: endpoint, path_prefix: "/docs", start_path: "/docs/index")
      end

      let(:sitemap) do
        [200, { "Content-Type" => "application/xml" },
         "<urlset><url><loc>https://docs.test/docs/elsewhere</loc></url></urlset>"]
      end

      before { stub_page("https://docs.test/docs/index", page_html("Index")) }

      # Naming a page to begin at is asking for what that page reaches; seeding
      # the whole site alongside it answers a question nobody asked.
      it "ignores the sitemap" do
        expect(result.map(&:title)).to eq(["Index"])
      end
    end

    context "with an endpoint confined to part of the site" do
      subject(:source) do
        create(:web_source, endpoint: endpoint, path_prefix: "/wiki/docs", start_path: "/wiki/index")
      end

      let(:endpoint) { create(:web_endpoint, base_url: "https://docs.test", path_prefix: "/wiki") }

      before do
        stub_page("https://docs.test/wiki/index", page_html("Index", links: ["/wiki/docs/a", "/elsewhere/b"]))
        stub_page("https://docs.test/wiki/docs/a", page_html("A"))
        stub_page("https://docs.test/elsewhere/b", page_html("B"))
      end

      it { expect(result.map(&:title)).to eq(["A"]) }

      # Nothing outside the endpoint's path is fetched at all — the link is not
      # even queued, so no request goes out carrying its credentials.
      it "never queues the link outside the endpoint" do
        result
        expect(run.items.pluck(:external_id)).not_to include("https://docs.test/elsewhere/b")
      end
    end

    # A validation refuses this, so it only happens when an admin narrows the
    # endpoint under a source that already exists.
    context "with a start page the endpoint no longer reaches" do
      subject(:source) do
        create(:web_source, endpoint: endpoint, path_prefix: "/wiki", start_path: "/index")
      end

      let(:endpoint) { create(:web_endpoint, base_url: "https://docs.test") }

      before { endpoint.update_column(:config, endpoint.config.merge("path_prefix" => "/wiki")) }

      it { expect { result }.to raise_error(Sources::Web::OutOfScopeError) }
    end

    context "with a page budget smaller than the site" do
      subject(:source) { create(:web_source, endpoint: endpoint, path_prefix: "/docs", max_pages: 2) }

      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a", "/docs/b"]))
        stub_page("https://docs.test/docs/a", page_html("A"))
        stub_page("https://docs.test/docs/b", page_html("B"))
      end

      it { expect(result.size).to eq(2) }

      # The whole point of the cap: a crawl that stopped early has not seen the
      # site, so absence from it must not be read as deletion.
      it "is not authoritative" do
        result
        expect(source.authoritative_scan?(run)).to be(false)
      end
    end

    context "with a link deeper than the depth limit" do
      subject(:source) { create(:web_source, endpoint: endpoint, path_prefix: "/docs", max_depth: 1) }

      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a"]))
        stub_page("https://docs.test/docs/a", page_html("A", links: ["/docs/b"]))
        stub_page("https://docs.test/docs/b", page_html("B"))
      end

      it { expect(result.map(&:title)).to contain_exactly("Index", "A") }
    end

    context "with a crawl resumed after a pass that stopped part-way" do
      before do
        stub_page("https://docs.test/docs", page_html("Index", links: ["/docs/a", "/docs/b"]))
        stub_page("https://docs.test/docs/a", page_html("A"))
        stub_page("https://docs.test/docs/b", page_html("B"))

        source.each_item(run) { |_item| break }
      end

      # Index comes round again because its row is resolved only *after* the
      # yield returns, and the break left before that. One page fetched twice is
      # the deliberate price of never resolving a row for work that didn't land.
      it "picks up where it left off, re-offering the page it was cut off on" do
        expect(result.map(&:title)).to contain_exactly("Index", "A", "B")
      end
    end
  end

  describe "#authoritative_scan?" do
    let(:result) { source.authoritative_scan?(run) }

    context "with a crawl that drained cleanly" do
      before do
        stub_page("https://docs.test/docs", page_html("Index"))
        source.each_item(run).to_a
      end

      it { expect(result).to be(true) }
    end

    context "with a crawl that has not run" do
      it { expect(result).to be(false) }
    end
  end

  describe "#read" do
    let(:result) { source.read("https://docs.test/docs/a") }

    context "with a page that still extracts" do
      before { stub_page("https://docs.test/docs/a", page_html("A")) }

      it { expect(result).to include("<h1>A</h1>") }
      it { expect(result).not_to include("<nav>") }
    end

    context "with a page that has gone" do
      before { stub_page("https://docs.test/docs/a", "", status: 404) }

      it { expect { result }.to raise_error(Sources::Web::UnreadableError) }
    end

    context "with a page that no longer extracts to anything" do
      before { stub_page("https://docs.test/docs/a", "<html><body><div id='root'></div></body></html>") }

      it { expect { result }.to raise_error(Ingestion::NothingReadable) }
    end
  end

  describe "#crawl_delay" do
    let(:result) { source.crawl_delay }

    context "with a crawl delay in robots.txt" do
      let(:robots_txt) { "User-agent: *\nCrawl-delay: 3\n" }

      it { expect(result).to eq(3.0) }
    end

    context "with the operator asking for a slower one than the site did" do
      subject(:source) { create(:web_source, endpoint: endpoint, crawl_delay_seconds: "5") }

      let(:robots_txt) { "User-agent: *\nCrawl-delay: 3\n" }

      it { expect(result).to eq(5.0) }
    end
  end
end
