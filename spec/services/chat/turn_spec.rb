require "rails_helper"

RSpec.describe Chat::Turn do
  subject(:turn) { described_class.new(conversation) }

  let(:conversation) { create(:conversation) }
  let(:segments) { turn.message.segments.reload }

  # Broadcasting is Turbo's job and needs no assertion here; what matters is the
  # sequence of segments a stream leaves behind.
  before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) }

  describe "#append" do
    context "when the model streams prose" do
      before do
        turn.append("Production credentials ")
        turn.append("rotate every 90 days.")
        turn.finish
      end

      it "leaves one text segment" do
        expect(segments.size).to eq(1)
      end

      it "joins the deltas" do
        expect(segments.first.content).to eq("Production credentials rotate every 90 days.")
      end
    end

    context "when a delta is blank" do
      before do
        turn.append("")
        turn.finish
      end

      it "starts no segment for it" do
        expect(segments).to be_empty
      end
    end
  end

  describe "#retrieval_started" do
    let(:outcome) { Retrieval::Outcome.new(hits: [], candidate_count: 0) }

    context "when the model searches mid-sentence" do
      before do
        turn.append("Let me check.")
        turn.retrieval_started(["credential rotation"])
        turn.retrieval_finished(outcome)
        turn.append("It rotates every 90 days.")
        turn.finish
      end

      # The ordering is the point: the transcript records the pause where it
      # happened rather than tidying the search away.
      it "leaves prose, retrieval, prose" do
        expect(segments.map(&:kind)).to eq(%w[text retrieval text])
      end

      it "closes the first text segment where the search interrupted it" do
        expect(segments.first.content).to eq("Let me check.")
      end

      it "starts a new text segment after the search" do
        expect(segments.last.content).to eq("It rotates every 90 days.")
      end

      it "keeps the queries on the retrieval segment" do
        expect(segments.second.queries).to eq(["credential rotation"])
      end
    end

    # The state the spinner renders. It only exists if the segment is written
    # before the search runs, not after it returns.
    context "while the search is still running" do
      before do
        turn.retrieval_started(["credential rotation"])
      end

      it "records the queries already" do
        expect(segments.first.queries).to eq(["credential rotation"])
      end

      it "has no result count yet" do
        expect(segments.first.candidate_count).to be_nil
      end
    end

    context "when the model searches without saying anything first" do
      before do
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(outcome)
        turn.finish
      end

      it "leaves no empty text segment in front of it" do
        expect(segments.map(&:kind)).to eq(["retrieval"])
      end
    end
  end

  describe "#fail!" do
    context "when the turn couldn't happen" do
      before { turn.fail!("Couldn't reach tensor.") }

      it "records why on the message" do
        expect(turn.message.error).to eq("Couldn't reach tensor.")
      end

      # A transport failure didn't *say* anything; writing the apology into a
      # text segment would make it indistinguishable from something the model
      # actually produced.
      it "writes nothing into the transcript as prose" do
        expect(segments).to be_empty
      end
    end

    context "when it fails after the model had already said something" do
      before do
        turn.append("Let me check.")
        turn.fail!("Couldn't reach tensor.")
      end

      it "keeps what was already said" do
        expect(segments.map(&:content)).to eq(["Let me check."])
      end
    end
  end
end
