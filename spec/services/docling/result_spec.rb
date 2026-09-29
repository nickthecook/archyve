require "rails_helper"

RSpec.describe Docling::Result do
  subject(:result) { described_class.new(raw) }

  # A real docling-serve response captured from converting spec/fixtures/files/sample.md.
  let(:raw) { JSON.parse(Rails.root.join("spec/fixtures/files/docling_response.json").read) }

  describe "#status" do
    it "reports success" do
      expect(result.status).to eq("success")
    end
  end

  describe "#title" do
    it "returns the document's title element" do
      expect(result.title).to eq("Archyve Test Document")
    end
  end

  describe "#markdown" do
    it "is nil because we request json only" do
      expect(result.markdown).to be_nil
    end
  end

  describe "#items" do
    let(:items) { result.items }
    let(:texts) { items.map(&:text) }

    it "returns one item per body element" do
      expect(items.size).to eq(14)
    end

    it "treats the title as a level-0 heading" do
      title = items.first
      expect(title).to have_attributes(label: "title", level: 0, heading?: true)
    end

    it "marks body text as a non-heading" do
      body = items.find { |i| i.label == "text" }
      expect(body.heading?).to be(false)
    end

    it "keeps section headers at their own depth" do
      expect(items.select(&:heading?).map(&:level)).to eq([0, 1, 1, 2, 2, 1])
    end

    # Docling reports inline fragments, not paragraphs — see Result#items.
    context "when a paragraph is hard-wrapped across source lines" do
      it "rejoins the lines into one item" do
        expect(texts).to include(
          "Archyve is a retrieval-augmented generation system. It ingests documents from " \
          "sources and makes them searchable."
        )
      end
    end

    context "when a paragraph contains a link and an emphasised run" do
      it "rejoins the fragments without stranding the punctuation after them" do
        expect(texts).to include(
          "Documents flow through Docling for extraction, then chunking, then embedding."
        )
      end
    end

    context "when a list item's text sits in a nested inline group" do
      let(:list_items) { items.select { |i| i.label == "list_item" } }

      it "returns one item per list item, carrying the nested text" do
        expect(list_items.map(&:text)).to eq(
          ["extraction, which calls Docling", "chunking, which is structure-aware", "embedding"]
        )
      end

      it "does not emit the blank list_item wrapper" do
        expect(texts).not_to include("")
      end
    end
  end
end
