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

    context "when a delta is empty" do
      before do
        turn.append("")
        turn.finish
      end

      it "starts no segment for it" do
        expect(segments.select(&:text?)).to be_empty
      end
    end

    # Models stream whitespace as its own chunks. Dropping those — which
    # `blank?` would — deletes every paragraph break and list newline, and the
    # answer arrives as "while the door is open:1.Open the battery cover".
    context "when the model streams its newlines separately" do
      before do
        turn.append("Steps:")
        turn.append("\n\n")
        turn.append("1. Open the cover.")
        turn.finish
      end

      it "keeps the breaks between the words" do
        expect(segments.first.content).to eq("Steps:\n\n1. Open the cover.")
      end
    end

    context "when the model streams whitespace before saying anything" do
      before do
        turn.append("\n")
        turn.append("Steps:")
        turn.finish
      end

      it "still records what it went on to say" do
        expect(segments.first.content).to eq("\nSteps:")
      end
    end
  end

  describe "#append_thinking" do
    context "when the model reasons before answering" do
      before do
        turn.append_thinking("The user wants the rotation window. ")
        turn.append_thinking("The handbook covers it.")
        turn.append("Credentials rotate every 90 days.")
        turn.finish
      end

      # Ordering is the point again: the working-out belongs before the answer
      # it produced, not folded into it.
      it "keeps the reasoning in its own segment, ahead of the prose" do
        expect(segments.map(&:kind)).to eq(%w[thinking text])
      end

      it "joins the thinking deltas" do
        expect(segments.first.content).to eq("The user wants the rotation window. The handbook covers it.")
      end

      it "keeps the reasoning out of the answer" do
        expect(segments.last.content).to eq("Credentials rotate every 90 days.")
      end
    end

    context "when the model reasons again after searching" do
      let(:outcome) { Retrieval::Outcome.new(hits: [], candidate_count: 0) }

      before do
        turn.append_thinking("Need to search for this.")
        turn.retrieval_started(["credential rotation"])
        turn.retrieval_finished(outcome)
        turn.append_thinking("Nothing came back.")
        turn.append("I couldn't find anything on that.")
        turn.finish
      end

      it "keeps each round's reasoning separate" do
        expect(segments.map(&:kind)).to eq(%w[thinking retrieval thinking text])
      end

      it "doesn't let the second round join the first" do
        expect(segments.first.content).to eq("Need to search for this.")
      end
    end

    # The flaky-provider case: the whole reply arrives on the analysis channel
    # and nothing is ever said. That is a turn that failed to answer, and the
    # transcript has to say so rather than showing a box with a disclosure in it.
    context "when the model reasons and then says nothing" do
      before do
        turn.append_thinking("We could answer this several ways.")
        turn.finish
      end

      it "records that it finished without answering" do
        expect(turn.message.reload.error).to eq("The model finished without answering.")
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

  describe "waiting for the model" do
    context "while the turn is still running" do
      it "reports itself in progress from the moment it exists" do
        expect(turn.message).to be_in_progress
      end

      it "says it is thinking, before anything has been said" do
        expect(turn.message.waiting_on).to eq("Thinking…")
      end
    end

    # The long gap: retrieval has returned and the model is re-reading six
    # chunks before its first token. This is the one that looked like a hang.
    context "after a search has returned but before the model speaks" do
      before do
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(Retrieval::Outcome.new(hits: [], candidate_count: 4))
      end

      it "says it is reading what came back" do
        expect(turn.message.waiting_on).to eq("Reading the results…")
      end
    end

    # Streaming prose is its own evidence of progress.
    context "while prose is streaming" do
      before { turn.append("Production credentials ") }

      it "shows nothing extra" do
        expect(turn.message.waiting_on).to be_nil
      end
    end

    context "once the turn is done" do
      before { turn.append("Done."); turn.finish }

      it "is no longer in progress" do
        expect(turn.message.reload).not_to be_in_progress
      end

      it "stops waiting on anything" do
        expect(turn.message.reload.waiting_on).to be_nil
      end
    end

    context "when the turn failed" do
      before { turn.fail!("Couldn't reach tensor.") }

      it "stops waiting rather than spinning behind the error" do
        expect(turn.message.reload).not_to be_in_progress
      end
    end
  end

  describe "#finish" do
    # Otherwise the page spins for good: the spinner renders on "nothing yet",
    # and nothing distinguishes that from a turn that ended having said nothing.
    context "when the model returned nothing at all" do
      before { turn.finish }

      it "says so rather than leaving the turn thinking" do
        expect(turn.message.error).to eq("The model finished without answering.")
      end
    end

    context "when the model searched but never wrote prose" do
      before do
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(Retrieval::Outcome.new(hits: [], candidate_count: 0))
        turn.finish
      end

      # The retrieval panel is on the page, so the turn isn't a blank box.
      it "does not call that an empty turn" do
        expect(turn.message.error).to be_nil
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
