require "rails_helper"

RSpec.describe Views::Documents::Detail do
  subject(:html) { described_class.new(document:).call }

  let(:document) { create(:document, status: "processed") }

  describe "a chunk's body" do
    before { create(:chunk, document:, position: 0, content: content, markdown: markdown, structure: structure) }

    let(:structure) { { "heading_path" => ["Manual", "Setup"] } }
    let(:content) { "Manual > Setup\n\nRun the *installer*." }

    context "when the chunk has a display form" do
      let(:markdown) { "Run the *installer*." }

      it "renders it as markup rather than as literal text" do
        expect(html).to include("<em>installer</em>")
      end

      it "shows the heading path once, in the card header rather than twice" do
        expect(html.scan("Setup").size).to eq(1)
      end
    end

    context "when the chunk predates the display form" do
      let(:markdown) { nil }

      it "falls back to the retrieval text, which is all it has" do
        expect(html).to include("Manual &gt; Setup")
      end
    end

    context "when the display form carries markup a document should not inject" do
      let(:markdown) { "before <script>alert(1)</script> after" }

      it "sanitizes it" do
        expect(html).not_to include("<script>")
      end
    end
  end
end
