require "rails_helper"

RSpec.describe Segment do
  describe "#for_history" do
    context "with a text segment" do
      subject(:segment) { create(:segment, content: "Credentials rotate every 90 days.") }

      it "replays what was said" do
        expect(segment.for_history).to eq("Credentials rotate every 90 days.")
      end
    end

    # Reasoning was never said to the person asking, and replaying a model's own
    # analysis invites it to continue from it rather than answer afresh.
    context "with a thinking segment" do
      subject(:segment) { create(:thinking_segment) }

      it "is left out of history" do
        expect(segment.for_history).to be_nil
      end
    end

    # Replayed for the same reason a past search is: a follow-up question about
    # what was read needs the passages, not a note that reading happened.
    context "with a reading segment" do
      subject(:segment) { create(:reading_segment) }

      before { create(:hit, :read, segment:, handle: 9) }

      it "says what was read, and how much of it" do
        expect(segment.for_history).to include("read Security Handbook, chunks 10–14 of 47")
      end

      it "replays the passages under the handles the model was given" do
        expect(segment.for_history).to include("[9] ")
      end
    end

    # A model that isn't told its last read failed will assume it succeeded and
    # answer from nothing.
    context "with a reading segment that was refused" do
      subject(:segment) { create(:reading_segment, reading: { "refusal" => "not_found" }) }

      it "says the read failed rather than dropping it from history" do
        expect(segment.for_history).to include("could not be read")
      end
    end

    # What a listing saw is what a follow-up like "read the second one" depends
    # on, even though none of it can be cited.
    context "with a listing of collections" do
      subject(:segment) { create(:listing_segment) }

      it "replays what it listed" do
        expect(segment.for_history).to include("Security Handbook (security-handbook, 12 documents)")
      end
    end

    context "with a listing of documents" do
      subject(:segment) { create(:listing_segment, :documents) }

      it "replays the ids, so a follow-up can read one" do
        expect(segment.for_history).to include("41 Credential rotation")
      end

      it "says how much of the collection it saw" do
        expect(segment.for_history).to include("documents 1–2 of 9 in Security Handbook")
      end
    end

    context "with a listing that was refused" do
      subject(:segment) { create(:listing_segment, :refused) }

      it "says the listing failed rather than dropping it from history" do
        expect(segment.for_history).to include("isn't in this chat's scope")
      end
    end
  end

  describe "#record_reading!" do
    subject(:segment) { create(:reading_segment, reading: nil) }

    let(:document) { create(:document, title: "Security Handbook") }
    let(:chunk) { create(:chunk, document:, position: 9) }

    before do
      segment.record_reading!(
        Retrieval::Reading.new(
          document:, from: 10, to: 10, total: 47,
          hits: [Retrieval::Hit.new(chunk:, document:, handle: 3)]
        )
      )
    end

    # Snapshotted rather than read through the chunk, which a reingest replaces.
    it "records the range on the segment" do
      expect(segment.range).to eq("chunk 10 of 47")
    end

    it "records the passage as a citable hit" do
      expect(segment.hits.map(&:handle)).to eq([3])
    end

    it "records what the model was shown, not a pointer to it" do
      expect(segment.hits.first.snippet).to eq(chunk.content)
    end
  end

  describe "#record_listing!" do
    subject(:segment) { create(:listing_segment, listing: nil) }

    let(:listing) do
      Retrieval::Listing.new(
        kind: :documents, title: "Security Handbook", to: 1, total: 9,
        entries: [{ "id" => 41, "title" => "Credential rotation", "source" => "Wiki", "chunks" => 14 }]
      )
    end

    before { segment.record_listing!(listing) }

    it "records what was listed" do
      expect(segment.listed_entries.first["title"]).to eq("Credential rotation")
    end

    it "records how much of the collection it saw" do
      expect(segment).to have_attributes(listed_from: 1, listed_to: 1, listed_total: 9)
    end

    # Nothing in a listing is a passage, so nothing in one may be cited.
    it "records no hits to cite" do
      expect(segment.hits).to be_empty
    end

    it "is not a segment a citation resolves against" do
      expect(segment).not_to be_sourced
    end
  end

  describe "#tokens_per_second" do
    context "with a segment the model generated" do
      subject(:segment) { create(:segment, token_count: 240, generation_ms: 4000) }

      it "is the tokens over the span they took" do
        expect(segment.tokens_per_second).to eq(60.0)
      end
    end

    # A search isn't generation, so there is nothing to divide.
    context "with a retrieval segment" do
      subject(:segment) { create(:retrieval_segment) }

      it "has no rate" do
        expect(segment.tokens_per_second).to be_nil
      end
    end

    # The span runs first delta to last, so a segment of one delta has none.
    context "with a segment whose first delta was its last" do
      subject(:segment) { create(:segment, token_count: 1, generation_ms: 0) }

      it "has no rate rather than an infinite one" do
        expect(segment.tokens_per_second).to be_nil
      end
    end

    context "with a segment from before this was recorded" do
      subject(:segment) { create(:segment, token_count: nil, generation_ms: nil) }

      it "has no rate" do
        expect(segment.tokens_per_second).to be_nil
      end
    end
  end

  describe "#record!" do
    subject(:segment) { create(:retrieval_segment) }

    let(:result) { segment.record!(outcome) }

    let(:document) { create(:document, title: "Security Handbook") }
    let(:chunk) { create(:chunk, document:, content: "Credentials rotate every 90 days.") }

    let(:hit) do
      Retrieval::Hit.new(chunk:, document:, distance: 0.18, score: 0.032, handle: 1)
    end

    context "when retrieval found something" do
      let(:outcome) { Retrieval::Outcome.new(hits: [hit], candidate_count: 14) }

      it "records the hit" do
        result
        expect(segment.hits.count).to eq(1)
      end

      it "keeps the handle the model was given" do
        result
        expect(segment.hits.first.handle).to eq(1)
      end

      it "records the pool the hit was chosen from" do
        result
        expect(segment.candidate_count).to eq(14)
      end

      # The transcript is a historical record; the corpus is not.
      it "copies what the model read rather than pointing at it" do
        result
        expect(segment.hits.first.snippet).to eq("Credentials rotate every 90 days.")
      end

      it "copies the document's title too" do
        result
        expect(segment.hits.first.document_title).to eq("Security Handbook")
      end

      it "is not a failure" do
        result
        expect(segment).not_to be_failed
      end
    end

    context "when the document is reingested afterwards" do
      let(:outcome) { Retrieval::Outcome.new(hits: [hit], candidate_count: 14) }

      before do
        result
        chunk.destroy!
      end

      it "keeps the citation readable" do
        expect(segment.hits.first.reload.snippet).to eq("Credentials rotate every 90 days.")
      end

      it "lets go of the chunk rather than taking the hit with it" do
        expect(segment.hits.first.reload.chunk_id).to be_nil
      end
    end

    context "when retrieval ran and found nothing" do
      let(:outcome) { Retrieval::Outcome.new(hits: [], candidate_count: 0) }

      it "records no hits" do
        result
        expect(segment.hits).to be_empty
      end

      it "did not fail" do
        result
        expect(segment).not_to be_failed
      end

      it "says so, so the model can be told the archive doesn't cover it" do
        result
        expect(segment).to be_found_nothing
      end
    end

    # The distinction the whole type exists for: an empty list and a broken
    # search must never look the same once they're on disk.
    context "when retrieval couldn't run" do
      let(:outcome) { Retrieval::Outcome.failed(:unreachable, server_name: "tensor") }

      it "records the failure" do
        result
        expect(segment).to be_failed
      end

      it "keeps which failure it was" do
        result
        expect(segment.failure_kind).to eq("unreachable")
      end

      it "is not mistaken for an empty archive" do
        result
        expect(segment).not_to be_found_nothing
      end
    end
  end
end
