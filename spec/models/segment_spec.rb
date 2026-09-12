require "rails_helper"

RSpec.describe Segment do
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
