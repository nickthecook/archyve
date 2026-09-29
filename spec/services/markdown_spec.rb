require "rails_helper"

RSpec.describe Markdown do
  describe ".to_html" do
    subject(:html) { described_class.to_html(text) }

    context "with GFM a document or a model might carry" do
      let(:text) { "A **bold** word and a | a | b |\n|---|---|\n| 1 | 2 |" }

      it "renders the markdown" do
        expect(html).to include("<strong>bold</strong>")
      end
    end

    context "with a table" do
      let(:text) { "| a | b |\n|---|---|\n| 1 | 2 |" }

      it "renders the GFM table extension" do
        expect(html).to include("<table>")
      end
    end

    context "with a link that leaves the app" do
      let(:text) { "[out](https://example.com)" }

      it "leashes it" do
        expect(html).to include('rel="nofollow noopener"').and include('target="_blank"')
      end
    end

    context "with a link that stays in the app" do
      let(:text) { "[here](/documents/1)" }

      it "leaves it alone" do
        expect(html).not_to include("nofollow")
      end
    end

    context "with HTML embedded in the text" do
      let(:text) { "hello <script>alert(1)</script>" }

      it "sanitizes rather than executes it" do
        expect(html).not_to include("<script>")
      end
    end

    context "with an image" do
      let(:text) { "![x](https://example.com/x.png)" }

      it "strips it, so the page never fetches a remote resource" do
        expect(html).not_to include("<img")
      end
    end

    # Chat::Prose layers this on top; document text must never get it.
    context "with something that looks like a citation" do
      let(:text) { "see [1] for more" }

      it "leaves the marker as written" do
        expect(html).to include("[1]")
      end
    end
  end
end
