require "rails_helper"

RSpec.describe Tools::Search do
  describe "#execute" do
    subject(:tool) { described_class.new(corpus:, handles:, observer:) }

    let(:result) { tool.execute(queries:) }

    let(:user) { create(:user) }
    let(:corpus) { instance_double(Retrieval::Corpus, label: "the Security Handbook") }
    let(:handles) { Retrieval::Handles.new }
    let(:observer) { nil }
    let(:queries) { ["credential rotation"] }

    let(:outcome) { Retrieval::Outcome.new(hits: [hit], candidate_count: 9) }
    let(:hit) do
      Retrieval::Hit.new(chunk:, document:, distance: 0.18, score: 0.032, handle: 1)
    end
    let(:document) { create(:document, title: "Security Handbook") }
    let(:chunk) { create(:chunk, document:, content: "Credentials rotate every 90 days.") }

    before do
      allow(Retrieval::Search).to receive(:new).and_return(instance_double(Retrieval::Search, call: outcome))
    end

    context "when the search finds something" do
      it "reports success" do
        expect(result[:status]).to eq("ok")
      end

      it "gives the model a handle to cite" do
        expect(result[:passages].first[:handle]).to eq(1)
      end

      # The handle cites the passage; the id addresses the document. Without
      # the id, a model that found nearly enough in chunk 12 has no way to ask
      # for chunk 13 — see Tools::Read.
      it "gives it the document's id, so it can read further" do
        expect(result[:passages].first[:id]).to eq(document.id)
      end

      it "says where in the document the passage sits, counting from 1" do
        expect(result[:passages].first[:chunk]).to eq(chunk.position + 1)
      end

      it "says how much document there is to read" do
        expect(result[:passages].first[:chunks]).to eq(1)
      end

      it "gives it the passage to read" do
        expect(result[:passages].first[:text]).to eq("Credentials rotate every 90 days.")
      end

      # A document id is the one identifier the model gets. It is not a link and
      # not a chunk: it addresses a document, and resolving it goes back through
      # the corpus — see Tools::Read for why that is enough.
      it "gives it no identifier it could follow or forge" do
        expect(result[:passages].first.keys).not_to include(:chunk_id, :url, :href)
      end
    end

    context "when the search runs and finds nothing" do
      let(:outcome) { Retrieval::Outcome.new(hits: [], candidate_count: 0) }

      it "says the search found nothing" do
        expect(result[:status]).to eq("no_matches")
      end

      it "names what was searched, so the model doesn't overclaim" do
        expect(result[:instruction]).to include("the Security Handbook")
      end
    end

    # The distinction the whole design turns on: an empty result set and a
    # broken search must never reach the model looking the same.
    context "when retrieval couldn't run" do
      let(:outcome) { Retrieval::Outcome.failed(:unreachable, server_name: "tensor") }

      it "does not report it as an empty archive" do
        expect(result[:status]).to eq("unavailable")
      end

      it "tells the model not to answer from its own knowledge" do
        expect(result[:instruction]).to include("do not answer from your own knowledge")
      end
    end

    context "when the model sends more queries than are useful" do
      let(:queries) { Array.new(9) { "query #{it}" } }
      let(:search) { instance_double(Retrieval::Search, call: outcome) }

      before { allow(Retrieval::Search).to receive(:new).and_return(search) }

      it "searches only the first few rather than refusing" do
        result
        expect(search).to have_received(:call).with(array_including, hash_including(:limit)) do |sent, _|
          expect(sent.size).to eq(described_class::MAX_QUERIES)
        end
      end
    end

    context "when the model sends duplicate or blank queries" do
      let(:queries) { ["rotation", "rotation", "  ", ""] }
      let(:search) { instance_double(Retrieval::Search, call: outcome) }

      before { allow(Retrieval::Search).to receive(:new).and_return(search) }

      it "searches each distinct one once" do
        result
        expect(search).to have_received(:call).with(["rotation"], anything)
      end
    end

    context "when the model sends no usable query at all" do
      let(:queries) { ["", "   "] }

      it "asks it to try again rather than reporting an empty archive" do
        expect(result[:error]).to include("at least one search phrase")
      end

      it "does not search" do
        result
        expect(Retrieval::Search).not_to have_received(:new)
      end
    end

    context "with an observer watching the turn" do
      let(:observer) { spy("observer") }

      it "tells it a search started, so the UI can show it running" do
        result
        expect(observer).to have_received(:retrieval_started).with(["credential rotation"])
      end

      it "hands it the outcome to record" do
        result
        expect(observer).to have_received(:retrieval_finished).with(outcome)
      end
    end
  end

  # Handles number the whole turn, not each search: a model that searches twice
  # and cites [2] must mean one passage, and the transcript has to agree with it.
  describe "handles across a turn" do
    subject(:tool) { described_class.new(corpus:, handles:) }

    let(:user) { create(:user) }
    let(:corpus) { instance_double(Retrieval::Corpus, label: "your whole archive") }
    let(:handles) { Retrieval::Handles.new }
    let(:document) { create(:document, title: "Security Handbook") }
    let(:chunk) { create(:chunk, document:, content: "Credentials rotate every 90 days.") }
    let(:outcome) do
      Retrieval::Outcome.new(
        hits: [Retrieval::Hit.new(chunk:, document:, distance: 0.18, score: 0.032, handle: 1)],
        candidate_count: 9
      )
    end

    before do
      allow(Retrieval::Search).to receive(:new).and_return(instance_double(Retrieval::Search, call: outcome))
    end

    it "carries on numbering rather than starting over" do
      tool.execute(queries: ["first"])
      expect(tool.execute(queries: ["second"])[:passages].first[:handle]).to eq(2)
    end
  end

  describe "#description" do
    subject(:tool) { described_class.new(corpus:, handles: Retrieval::Handles.new) }

    let(:corpus) { instance_double(Retrieval::Corpus, label: "the Security Handbook") }

    # Without this the model reports that the archive lacks something when the
    # truth is that the user narrowed the scope.
    it "tells the model what it is searching" do
      expect(tool.description).to include("the Security Handbook")
    end

    it "tells it the scope is not its to choose" do
      expect(tool.description).to include("cannot choose which documents")
    end
  end
end
