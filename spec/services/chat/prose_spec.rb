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

      it "removes it rather than running it" do
        expect(html).not_to include("<script")
      end

      it "drops the tag and keeps the prose around it" do
        expect(html).to include("Before", "after")
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
    subject(:prose) { described_class.new(content, hits:, popover_id: ->(hit) { "card_#{hit.handle}" }) }

    let(:html) { prose.call }
    let(:hit) { create(:hit, handle: 1, document_title: "Handbook") }
    let(:hits) { { 1 => hit } }

    context "with a handle that was retrieved" do
      let(:content) { "Rotate them [1]." }

      it "opens that hit's card" do
        expect(html).to include(%(popovertarget="card_1"))
      end

      it "anchors the card to the marker" do
        expect(html).to include("anchor-name: --card_1")
      end

      it "reports the hit as cited" do
        prose.call
        expect(prose.cited).to eq([hit])
      end
    end

    # The card carries the links, so the marker never does.
    context "when the document no longer exists" do
      let(:hit) { create(:hit, chunk: nil, document: nil, handle: 1, document_title: "Handbook") }
      let(:content) { "Rotate them [1]." }

      it "still opens a card" do
        expect(html).to include(%(popovertarget="card_1"))
      end

      it "puts no link in the prose" do
        expect(html).not_to include("href=")
      end
    end

    context "when the same handle is cited twice" do
      let(:content) { "Rotate them [1], then check [1]." }

      it "reports it once" do
        prose.call
        expect(prose.cited).to eq([hit])
      end
    end

    # The model can invent [7] when six results came back, and the honest
    # rendering of an invented citation is the literal thing it wrote.
    context "with a handle that was not retrieved" do
      let(:content) { "Rotate them [7]." }

      it "leaves it as plain text" do
        expect(html).to include("[7]")
      end

      it "opens nothing" do
        expect(html).not_to include("popovertarget")
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

      it "opens nothing" do
        expect(html).not_to include("popovertarget")
      end
    end

    # Models write what they like: gpt-oss emits 【1】, others ［1］.
    context "with a bracket a model reached for instead" do
      let(:content) { "Rotate them 【1】." }

      it "still cites it" do
        expect(html).to include(%(popovertarget="card_1"))
      end
    end

    context "with several handles in one bracket" do
      let(:content) { "Both of these [1, 7]." }

      it "keeps the citation that resolved" do
        expect(html).to include(%(popovertarget="card_1"))
      end

      it "keeps the one that didn't as text" do
        expect(html).to include("[7]")
      end
    end
  end
end
