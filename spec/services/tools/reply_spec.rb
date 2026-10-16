require "rails_helper"

RSpec.describe Tools::Reply do
  describe ".call" do
    subject(:rendered) { described_class.call(payload) }

    context "with a passage carrying markdown" do
      let(:payload) do
        {
          status: "ok",
          scope: "your whole archive",
          passages: [
            {
              handle: 1, id: 412, document: "todo.md", section: "The web source › Phase 4",
              chunk: 8, chunks: 47,
              text: "## Phase 4\n\n- **SPA detection.** Check for a root div.\n- Then fetch."
            }
          ]
        }
      end

      it "keeps the newlines the markdown needs" do
        expect(rendered).to include("## Phase 4\n\n- **SPA detection.**")
      end

      it "escapes nothing" do
        expect(rendered).not_to include('\n')
      end

      it "delimits the passage by its handle" do
        expect(rendered).to include("--- [1] todo.md · The web source › Phase 4")
      end

      it "locates the passage in its document" do
        expect(rendered).to include("chunk 8 of 47 · document id 412")
      end

      it "states the facts of the call as lines" do
        expect(rendered).to start_with("status: ok\nscope: your whole archive")
      end
    end

    context "with several passages" do
      let(:payload) do
        {
          passages: [
            { handle: 1, document: "a.md", chunk: 8, chunks: 47, text: "first" },
            { handle: 2, document: "a.md", chunk: 3, chunks: 47, text: "second" }
          ]
        }
      end

      it "delimits each one" do
        expect(rendered.scan(/^--- \[\d\]/).size).to eq(2)
      end

      it "keeps them in the order given" do
        expect(rendered.index("first")).to be < rendered.index("second")
      end
    end

    context "with a passage that has no document of its own" do
      let(:payload) { { id: 412, document: "todo.md", passages: [{ handle: 3, chunk: 8, text: "body" }] } }

      it "names it by handle alone, with no trailing separator" do
        expect(rendered).to include("--- [3]\n")
      end

      it "still locates the chunk" do
        expect(rendered).to include("    chunk 8\n")
      end
    end

    context "with the instruction a tool wants acted on" do
      let(:payload) { { status: "ok", instruction: "Say so rather than answering from memory." } }

      it "puts it last" do
        expect(rendered).to end_with("Say so rather than answering from memory.")
      end
    end

    context "with a paged span" do
      let(:payload) { { chunks: { from: 1, to: 12, total: 47 } } }

      it "reads as a range" do
        expect(rendered).to eq("chunks: 1–12 of 47")
      end
    end

    context "with a span that is only a total" do
      let(:payload) { { chunks: { total: 47 } } }

      it "reads as a count" do
        expect(rendered).to eq("chunks: 47 total")
      end
    end

    context "with listing rows" do
      let(:payload) do
        {
          status: "ok",
          collections: [
            { "name" => "Handbook", "slug" => "handbook", "documents" => 12, "sources" => %w[Wiki Drive] }
          ]
        }
      end

      it "gives each row a line" do
        expect(rendered).to include("  name: Handbook · slug: handbook · documents: 12")
      end

      it "joins a row's list values" do
        expect(rendered).to include("sources: Wiki, Drive")
      end
    end

    context "with an empty row set" do
      let(:payload) { { status: "no_collections", collections: [] } }

      it "says nothing about it rather than emitting a bare label" do
        expect(rendered).to eq("status: no_collections")
      end
    end

    context "with something that is not a hash" do
      let(:payload) { RubyLLM::Tool::Halt.new("stop") }

      it "passes it through untouched" do
        expect(rendered).to be(payload)
      end
    end
  end
end
