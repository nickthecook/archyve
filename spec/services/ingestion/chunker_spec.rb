require "rails_helper"

RSpec.describe Ingestion::Chunker do
  subject(:chunker) { described_class.new }

  def item(text, label: "text", level: nil, page: nil, markdown: text)
    Docling::Result::Item.new(text: text, markdown: markdown, label: label, level: level, page: page)
  end

  def result_with(items)
    instance_double(Docling::Result, items: items)
  end

  describe "#chunk" do
    let(:result) { chunker.chunk(result_with(items)) }

    context "with a short document under the target size" do
      let(:items) do
        [
          item("Doc Title", label: "title", level: 0),
          item("Intro", label: "section_header", level: 1),
          item("Hello world.")
        ]
      end

      it "returns a single chunk" do
        expect(result.size).to eq(1)
      end

      it "prefixes the content with the heading breadcrumb" do
        expect(result.first.content).to eq("Doc Title > Intro\n\nHello world.")
      end

      it "records the heading path in structure" do
        expect(result.first.structure[:heading_path]).to eq(["Doc Title", "Intro"])
      end
    end

    context "with sections that together exceed the target size" do
      subject(:chunker) { described_class.new(target_chars: 30) }

      let(:items) do
        [
          item("A", label: "section_header", level: 1),
          item("first paragraph here"),
          item("B", label: "section_header", level: 1),
          item("second paragraph here")
        ]
      end

      it "splits into a chunk per section at the target boundary" do
        expect(result.size).to eq(2)
      end

      it "keeps each section under its own breadcrumb" do
        expect(result.map(&:content)).to eq(["A\n\nfirst paragraph here", "B\n\nsecond paragraph here"])
      end
    end

    context "with a single block larger than the max size" do
      subject(:chunker) { described_class.new(target_chars: 20, max_chars: 25, overlap_chars: 5) }

      let(:items) { [item("word " * 20)] }

      it "splits the block into several chunks" do
        expect(result.size).to be > 1
      end

      it "keeps every chunk within the max size" do
        expect(result.map { |chunk| chunk.content.length }).to all(be <= 25)
      end
    end

    context "with body text and no headings" do
      let(:items) { [item("Just some text.")] }

      it "produces content without a breadcrumb" do
        expect(result.first.content).to eq("Just some text.")
      end

      it "omits a blank heading_path from structure" do
        expect(result.first.structure).not_to have_key(:heading_path)
      end
    end

    context "with page provenance on the blocks" do
      let(:items) do
        [
          item("Sec", label: "section_header", level: 1),
          item("text one", page: 2),
          item("text two", page: 1)
        ]
      end

      it "records the sorted unique pages" do
        expect(result.first.structure[:pages]).to eq([1, 2])
      end
    end
    context "with inline markup and a list" do
      let(:items) do
        [
          item("Doc Title", label: "title", level: 0),
          item("Intro", label: "section_header", level: 1),
          item("Flows through Docling.", markdown: "Flows through [Docling](https://d.example)."),
          item("first", label: "list_item", markdown: "**first**"),
          item("second", label: "list_item")
        ]
      end

      it "keeps the breadcrumb out of the display form, which the card has from structure" do
        expect(result.first.markdown).not_to include("Doc Title")
      end

      it "emits no heading when every block shares one, since the card shows it" do
        expect(result.first.markdown).not_to include("###")
      end

      it "preserves the inline markup docling reported" do
        expect(result.first.markdown).to include("[Docling](https://d.example).")
      end

      it "runs consecutive list items together as one list" do
        expect(result.first.markdown).to end_with("- **first**\n- second")
      end

      it "leaves content as the retrieval form, breadcrumb and all" do
        expect(result.first.content).to start_with("Doc Title > Intro\n\n")
      end
    end

    context "with a single block larger than the max size" do
      subject(:chunker) { described_class.new(target_chars: 40, max_chars: 50) }

      let(:items) { [item("word " * 40)] }

      it "gives the split pieces no display form, because the markup spans the cut" do
        expect(result.map(&:markdown)).to all(be_nil)
      end
    end
    context "with a chunk spanning two sections" do
      let(:items) do
        [
          item("Doc Title", label: "title", level: 0),
          item("Alpha", label: "section_header", level: 1),
          item("first body"),
          item("Beta", label: "section_header", level: 1),
          item("second body")
        ]
      end

      it "names each section below the common prefix, which the card cannot show" do
        expect(result.first.markdown).to eq("### Alpha\n\nfirst body\n\n### Beta\n\nsecond body")
      end

      it "still records only the shared prefix in structure" do
        expect(result.first.structure[:heading_path]).to eq(["Doc Title"])
      end
    end
  end
end
