require "rails_helper"

RSpec.describe Views::Conversations::CitationCard do
  describe "#call" do
    subject(:card) { described_class.new(hit:, id: "card_1") }

    let(:result) { card.call }

    let(:document) { create(:document, source:, url: "https://wiki.example.com/books/ops/page/clearances") }
    let(:source) { create(:bookstack_source) }
    let(:chunk) { create(:chunk, document:) }
    let(:hit) { create(:hit, :reachable, chunk:, document:, snippet: "Keep 1 in. clear of combustibles.") }

    it "shows what the model was shown" do
      expect(result).to include("Keep 1 in. clear of combustibles.")
    end

    it "is the popover its marker names" do
      expect(result).to include(%(id="card_1"), %(popover="auto"))
    end

    context "when the owner can open the document from a source that links out" do
      it "links to the source" do
        expect(result).to include(%(href="https://wiki.example.com/books/ops/page/clearances"))
      end

      it "names the source" do
        expect(result).to include("Open in #{source.type_label}")
      end

      it "links to the passage in Archyve" do
        expect(result).to include(%(href="/documents/#{document.id}#chunk_#{chunk.id}"))
      end
    end

    # A fixed-set agent draws on collections its user may not read.
    context "when the owner can't open the document" do
      let(:hit) { create(:hit, chunk:, document:, snippet: "Keep 1 in. clear of combustibles.") }

      it "still links to the source" do
        expect(result).to include("https://wiki.example.com/books/ops/page/clearances")
      end

      it "offers no way into Archyve" do
        expect(result).not_to include("/documents/")
      end

      it "still shows the passage" do
        expect(result).to include("Keep 1 in. clear of combustibles.")
      end
    end

    context "when the source has no links to hand out" do
      let(:source) { create(:manual_upload_source) }
      let(:hit) { create(:hit, chunk:, document:, snippet: "Keep 1 in. clear of combustibles.") }

      it "says there is nowhere to go" do
        expect(result).to include("Cannot link to this source")
      end

      it "still shows the passage" do
        expect(result).to include("Keep 1 in. clear of combustibles.")
      end
    end

    # Reingestion replaced the chunk; the document is still there.
    context "when the chunk it cited no longer exists" do
      let(:hit) { create(:hit, :reachable, chunk: nil, document:, snippet: "Keep 1 in. clear.") }

      it "links to the document instead" do
        expect(result).to include(%(href="/documents/#{document.id}"))
      end

      it "names no fragment" do
        expect(result).not_to include("#chunk_")
      end
    end

    context "when the document no longer exists" do
      let(:hit) { create(:hit, chunk: nil, document: nil, document_title: "Handbook", snippet: "Keep 1 in. clear.") }

      it "shows the title it was cited under" do
        expect(result).to include("Handbook")
      end

      it "says there is nowhere to go" do
        expect(result).to include("Cannot link to this source")
      end
    end
  end
end
