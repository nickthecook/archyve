require "rails_helper"

RSpec.describe Chat::Prose do
  subject(:html) { described_class.call(content, hits:) }

  let(:hits) { {} }

  describe "markdown" do
    context "with emphasis and headings" do
      let(:content) { "## Clearances\n\nKeep **1 in.** clear." }

      it "renders the heading" do
        expect(html).to include("<h2>Clearances</h2>")
      end

      it "renders the emphasis" do
        expect(html).to include("<strong>1 in.</strong>")
      end
    end

    # The dialect models actually emit.
    context "with a GFM table" do
      let(:content) { "| Step | Why |\n|---|---|\n| Frame it | Clearance |" }

      it "renders it as a table" do
        expect(html).to include("<table>", "<th>Step</th>", "<td>Frame it</td>")
      end
    end

    # A model writing a list of lines means them as lines; commonmark's "a
    # single newline is a space" would run them into one paragraph.
    context "with single newlines inside a paragraph" do
      let(:content) { "One thing.\nAnother thing." }

      it "keeps them apart" do
        expect(html).to include("<br>")
      end
    end
  end

  describe "what the model is not trusted with" do
    context "when the completion contains a script tag" do
      let(:content) { "Before <script>alert(1)</script> after" }

      it "escapes it rather than running it" do
        expect(html).not_to include("<script")
      end

      it "shows it as the string it is" do
        expect(html).to include("&lt;script&gt;")
      end
    end

    # A document carrying an injected image would otherwise make the page fetch
    # it on the reader's behalf.
    context "when the completion contains an image" do
      let(:content) { %(Look <img src="http://example.com/pixel.png">) }

      it "is stripped" do
        expect(html).not_to include("<img")
      end
    end

    context "when the model links somewhere" do
      let(:content) { "See https://example.com/page" }

      it "leashes the link" do
        expect(html).to include('rel="nofollow noopener"')
      end
    end
  end

  describe "citations" do
    let(:document) { create(:document, title: "Handbook") }
    let(:chunk) { create(:chunk, document:) }
    let(:hit) { create(:hit, :reachable, chunk:, document:, handle: 1, document_title: "Handbook") }
    let(:hits) { { 1 => hit } }

    context "with a handle that was retrieved" do
      let(:content) { "Rotate them [1]." }

      it "links it straight to the chunk it cited" do
        expect(html).to include(%(href="/documents/#{document.id}#chunk_#{chunk.id}"))
      end
    end

    # Reingestion destroys a document's chunks and makes new ones, so an old
    # transcript's hit can outlive the passage it named. The citation still has
    # to lead somewhere.
    context "when the chunk it cited no longer exists" do
      let(:hit) { create(:hit, :reachable, chunk: nil, document:, handle: 1, document_title: "Handbook") }
      let(:content) { "Rotate them [1]." }

      it "links to the document instead" do
        expect(html).to include(%(href="/documents/#{document.id}"))
      end

      it "names no fragment" do
        expect(html).not_to include("#chunk_")
      end
    end

    # Nothing to follow, but the handle is still what the answer was based on —
    # so it renders as a citation, just not as a link.
    context "when the document no longer exists" do
      let(:hit) { create(:hit, chunk: nil, document: nil, handle: 1, document_title: "Handbook") }
      let(:content) { "Rotate them [1]." }

      it "renders the marker without a link" do
        expect(html).not_to include("href=")
      end
    end

    # A fixed-set agent draws on collections its user may not read. The citation
    # still marks what the answer rests on, but doesn't hand them the document.
    context "when the conversation's owner can't open the document" do
      let(:hit) { create(:hit, chunk:, document:, handle: 1, document_title: "Handbook") }
      let(:content) { "Rotate them [1]." }

      it "renders the marker without a link" do
        expect(html).not_to include("href=")
      end

      it "still renders the marker" do
        expect(html).to include(">1</a>")
      end
    end

    # The model can invent [7] when six results came back, and the honest
    # rendering of an invented citation is the literal thing it wrote.
    context "with a handle that was not retrieved" do
      let(:content) { "Rotate them [7]." }

      it "leaves it as plain text" do
        expect(html).to include("[7]")
      end

      it "links nothing" do
        expect(html).not_to include("<a")
      end
    end

    # `results[1]` in a code sample is an array index, not a citation.
    context "inside a code span" do
      let(:content) { "Call `results[1]` on it." }

      it "leaves the brackets alone" do
        expect(html).to include("<code>results[1]</code>")
      end
    end

    context "inside a fenced block" do
      let(:content) { "```ruby\nresults[1]\n```" }

      it "leaves the brackets alone" do
        expect(html).to include("results[1]")
      end

      it "links nothing" do
        expect(html).not_to include("<a")
      end
    end

    # Models write what they like: gpt-oss emits 【1】, others ［1］.
    context "with a bracket a model reached for instead" do
      let(:content) { "Rotate them 【1】." }

      it "still links it" do
        expect(html).to include(%(href="/documents/#{document.id}#chunk_#{chunk.id}"))
      end
    end

    context "with several handles in one bracket" do
      let(:hits) { { 1 => hit } }
      let(:content) { "Both of these [1, 7]." }

      it "keeps the citation that resolved" do
        expect(html).to include(%(href="/documents/#{document.id}#chunk_#{chunk.id}"))
      end

      it "keeps the one that didn't as text" do
        expect(html).to include("[7]")
      end
    end
  end
end
