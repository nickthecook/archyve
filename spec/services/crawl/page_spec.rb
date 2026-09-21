require "rails_helper"

RSpec.describe Crawl::Page do
  subject(:page) { described_class.parse(html, url: "https://docs.test/docs/install", content_selector: selector) }

  let(:selector) { nil }
  let(:prose) { "Unpack the archive and run the installer, then wait for it to finish. " * 4 }

  let(:html) do
    <<~HTML
      <html><head><title>Install</title></head><body>
        <nav><a href="/docs/a">A</a><a href="/docs/b">B</a></nav>
        <div id="sidebar"><ul><li><a href="/docs/c">C</a></li></ul></div>
        <main><h1>Installing</h1><p>#{prose}</p><h2>Afterwards</h2><p>#{prose}</p></main>
        <footer><a href="/privacy">Privacy</a><p>Copyright someone, all rights reserved.</p></footer>
      </body></html>
    HTML
  end

  describe ".parse" do
    context "with a page whose article sits in <main>" do
      it "keeps the article" do
        expect(page.content.text).to include("Unpack the archive")
      end

      # Repeated across every page of a site, boilerplate would put the same
      # large span in every chunk of every document.
      it "drops the navigation, sidebar and footer" do
        expect(page.content.text).not_to include("Copyright someone")
      end

      # Ingestion::Chunker builds each chunk's heading path out of these.
      it "keeps the headings" do
        expect(page.to_html).to include("<h1>Installing</h1>").and include("<h2>Afterwards</h2>")
      end

      it { expect(page.title).to eq("Install") }
      it { expect(page).to be_readable }
    end

    # Links are read before extraction throws the navigation away — which is
    # the only place most of a site's links are.
    describe "#hrefs" do
      it { expect(page.hrefs).to include("/docs/a", "/docs/c", "/privacy") }

      context "with a link marked nofollow" do
        let(:html) { '<html><body><a href="/docs/a" rel="nofollow">A</a></body></html>' }

        it { expect(page.hrefs).to be_empty }
      end
    end

    describe "#link_base" do
      context "with no base element" do
        it { expect(page.link_base).to eq("https://docs.test/docs/install") }
      end

      context "with a base element" do
        let(:html) { '<html><head><base href="https://docs.test/docs/"></head><body></body></html>' }

        it { expect(page.link_base).to eq("https://docs.test/docs/") }
      end
    end

    context "with no <main> to believe" do
      let(:html) do
        <<~HTML
          <html><head><title>Install</title></head><body>
            <div class="nav"><a href="/docs/a">A</a><a href="/docs/b">B</a></div>
            <div class="post"><h1>Installing</h1><p>#{prose}</p><p>#{prose}</p></div>
          </body></html>
        HTML
      end

      it "scores its way to the article" do
        expect(page.content.text).to include("Unpack the archive")
      end

      it { expect(page.content.text).not_to include(">A<") }
    end

    context "with a content selector naming the article outright" do
      let(:selector) { "#handwritten" }
      let(:html) do
        <<~HTML
          <html><body><main><p>#{prose}</p></main>
          <div id="handwritten"><p>The part that actually matters, at length and then some.</p></div>
          </body></html>
        HTML
      end

      it "believes it over the landmark it would otherwise pick" do
        expect(page.content.text).to include("actually matters")
      end
    end

    # A client-rendered page parses fine and extracts to near-nothing. It must
    # report rather than be stored as an empty document.
    context "with a client-rendered page" do
      let(:html) { '<html><head><title>App</title></head><body><div id="root"></div></body></html>' }

      it { expect(page).not_to be_readable }
    end

    context "with a page that tells crawlers to stay away" do
      let(:html) { '<html><head><meta name="robots" content="noindex, nofollow"></head><body></body></html>' }

      it { expect(page).to be_noindex }
      it { expect(page).to be_nofollow }
    end

    # Real pages are tag soup; the HTML5 parser recovers from it the way a
    # browser does rather than giving up at the first unclosed tag.
    context "with unclosed tags" do
      let(:html) { "<html><body><main><p>#{prose}<p>#{prose}</main></body>" }

      it { expect(page).to be_readable }
    end

    context "with a title only in an h1" do
      let(:html) { "<html><body><main><h1>Installing</h1><p>#{prose}</p></main></body></html>" }

      it { expect(page.title).to eq("Installing") }
    end
  end

  # The version token is a hash of exactly these bytes, so anything that churns
  # per-request must not reach them.
  describe "#to_html" do
    it { expect(page.to_html).to include("<title>Install</title>") }

    context "with the same article served twice with a different CSRF token" do
      let(:other) do
        described_class.parse(
          html.sub("<body>", '<body><meta name="csrf" content="rotating">'),
          url: "https://docs.test/docs/install"
        )
      end

      it "produces identical bytes" do
        expect(other.to_html).to eq(page.to_html)
      end
    end
  end
end
