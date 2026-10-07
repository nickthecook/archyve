require "rails_helper"

RSpec.describe Views::Conversations::Retrieval do
  describe "#call" do
    subject(:retrieval) { described_class.new(segment:) }

    let(:result) { retrieval.call }
    let(:segment) { create(:retrieval_segment) }
    let(:document) { create(:document, title: "SHS-2920 manual") }

    # The panel is created the moment the model stops to search, so a reader who
    # expanded it sees it before anything has come back. Saying "nothing
    # matched" then is a claim about the archive, not about the search, and it
    # is how a working search comes to look like a broken one.
    context "while the search is still running" do
      let(:segment) { create(:retrieval_segment, candidate_count: nil) }

      it "says it is still searching" do
        expect(result).to include("Searching the archive…")
      end

      it "does not claim the archive had nothing" do
        expect(result).not_to include("scope matched")
      end

      it "still shows what it is searching for" do
        expect(result).to include("credential rotation")
      end
    end

    context "once the search has returned empty-handed" do
      let(:segment) { create(:retrieval_segment, candidate_count: 0) }

      it "says the archive had nothing" do
        expect(result).to include("scope matched")
      end
    end

    # Expanding the results is how a reader checks an answer against what
    # retrieval actually returned; getting from a snippet to the passage in its
    # document shouldn't then mean hunting for it.
    context "when a hit's chunk is still there" do
      let(:chunk) { create(:chunk, document:) }

      before { create(:hit, segment:, chunk:, document:, handle: 1) }

      it "makes the card a link to that chunk" do
        expect(result).to include(%(href="/documents/#{document.id}#chunk_#{chunk.id}"))
      end

      it "keeps the snippet inside the link" do
        expect(result).to include("Production datastore credentials rotate every 90 days.")
      end
    end

    context "when a hit's document is gone" do
      before { create(:hit, segment:, chunk: nil, document: nil, handle: 1, document_title: "Retired manual") }

      it "links nothing" do
        expect(result).not_to include("<a")
      end

      # The record of what the model was shown survives the document it came
      # from — that is the more useful half of an old transcript.
      it "still shows what was retrieved" do
        expect(result).to include("Retired manual")
      end
    end

    # The enclosing details is itself a `group` for the chevron, so an unnamed
    # group on the card would accent every title whenever the pointer was
    # anywhere in the panel.
    context "with several followable hits" do
      before do
        create(:hit, segment:, chunk: create(:chunk, document:), document:, handle: 1)
        create(:hit, segment:, chunk: create(:chunk, document:), document:, handle: 2)
      end

      it "scopes the card hover to the card" do
        expect(result).to include("group/hit").and include("group-hover/hit:text-accent")
      end

      it "does not put a bare group on the cards" do
        expect(result).not_to include("group-hover:text-accent")
      end
    end
  end
end
