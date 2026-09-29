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

    describe "the display form" do
      let(:markdown) { items.map(&:markdown) }

      it "puts back the link docling flattened into a bare fragment" do
        expect(markdown).to include(
          "Documents flow through [Docling](https://docling-project.github.io/) for extraction, " \
          "then *chunking*, then embedding."
        )
      end

      it "puts back emphasis inside a list item" do
        expect(markdown).to include("extraction, which calls **Docling**")
      end

      it "matches the plain form wherever the source carried no markup" do
        plain = items.find { it.text == "Each stage is a job:" }
        expect(plain.markdown).to eq(plain.text)
      end
    end
    # A PDF's text is not markdown, and rendering it as if it were is how a door
    # manual struck half a sentence through. Exercised through the real renderer
    # because the bug is in what commonmark makes of the string, not the string.
    describe "text that a markdown renderer would misread" do
      subject(:rendered) { Markdown.to_html(item.markdown).strip }

      let(:item) { described_class.new(raw_for(source)).items.first }

      def raw_for(text)
        { "document" => { "json_content" => {
          "body" => { "children" => [{ "$ref" => "#/texts/0" }] },
          "texts" => [{ "self_ref" => "#/texts/0", "label" => "text", "text" => text, "children" => [] }]
        } } }
      end

      context "when the text contains tildes" do
        let(:source) { "Bee~ree ~reep Normal Authentication Mode Bee~ree" }

        it "does not strike it through" do
          expect(rendered).to eq("<p>Bee~ree ~reep Normal Authentication Mode Bee~ree</p>")
        end
      end

      context "when a numbered step opens the text" do
        let(:source) { "1. Touch the number pad 2. Enter Pin Number" }

        it "stays a paragraph rather than becoming an ordered list" do
          expect(rendered).to eq("<p>1. Touch the number pad 2. Enter Pin Number</p>")
        end
      end

      context "when a dash opens the text" do
        let(:source) { "- Force Lock features" }

        it "stays a paragraph rather than becoming a bullet" do
          expect(rendered).to eq("<p>- Force Lock features</p>")
        end
      end

      context "when a hash opens the text" do
        let(:source) { "# S9116BI ED:02" }

        it "stays a paragraph rather than becoming a heading" do
          expect(rendered).to eq("<p># S9116BI ED:02</p>")
        end
      end

      context "when the text carries other inline syntax" do
        let(:source) { "use snake_case_names and *stars* and a | pipe" }

        it "renders every character as written" do
          expect(rendered).to eq("<p>use snake_case_names and *stars* and a | pipe</p>")
        end
      end
    end
    # Docling has two shapes for the same document, and which one it picks is not
    # ours to predict — a raw HTML block in the markdown is enough to switch it.
    # Where the flat shape hangs every element off the body, this one has a
    # heading own the section beneath it, so the walk has to descend.
    context "when docling nests the document under its headings" do
      let(:raw) { JSON.parse(Rails.root.join("spec/fixtures/files/docling_nested_response.json").read) }

      it "returns every element rather than collapsing the document into its title" do
        expect(items.map(&:text)).to eq(
          ["Nested Doc", "Opening paragraph.", "Section One", "Body under the section.",
           "An embedded HTML block.", "Closing paragraph."]
        )
      end

      it "keeps the headings as headings" do
        expect(items.select(&:heading?).map(&:text)).to eq(["Nested Doc", "Section One"])
      end

      it "leaves body text chunkable, which a swallowed document is not" do
        expect(Ingestion::Chunker.new.chunk(result)).not_to be_empty
      end
    end
  end
end
