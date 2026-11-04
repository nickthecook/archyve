require "rails_helper"

RSpec.describe Chat::Turn do
  subject(:turn) { described_class.new(message) }

  let(:conversation) { create(:conversation) }

  # The empty turn Chat::Ask opens in the request. Everything here fills it in.
  let(:message) { create(:message, conversation:, role: "assistant", position: 2) }
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

  describe "the turn itself" do
    # It was opened by the request that asked the question. Creating another one
    # here would put a second, empty turn in the transcript.
    it "fills in the message it was given rather than opening one" do
      turn.append("Credentials rotate.")
      expect(conversation.messages.reload.select(&:assistant?)).to eq([message])
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

  describe "#listing_started" do
    let(:listing) do
      Retrieval::Listing.new(kind: :collections, to: 1, total: 1,
        entries: [{ "name" => "Security Handbook", "slug" => "security-handbook",
                    "documents" => 12, "sources" => ["Wiki"] }])
    end

    context "when the model walks the archive mid-sentence" do
      before do
        turn.append("Let me see what is here.")
        turn.listing_started
        turn.listing_finished(listing)
        turn.append("Two collections.")
        turn.finish
      end

      it "leaves prose, listing, prose" do
        expect(segments.map(&:kind)).to eq(%w[text listing text])
      end

      it "keeps what was listed on the listing segment" do
        expect(segments.second.listed_entries.first["slug"]).to eq("security-handbook")
      end

      # Nothing in a listing is a passage, so a citation must not resolve into
      # one — see Segment#sourced?.
      it "adds nothing to the turn's citation namespace" do
        expect(segments.second.hits).to be_empty
      end
    end

    # The state the spinner renders. It only exists if the segment is written
    # before the listing runs, not after it returns.
    context "while the listing is still running" do
      before { turn.listing_started }

      it "has nothing recorded yet" do
        expect(segments.first.listing).to be_nil
      end
    end
  end

  describe "#tool_started" do
    context "when the model checks something mid-sentence" do
      before do
        turn.append("Let me look at the queues.")
        turn.tool_started("check_queues", "the job queues")
        turn.tool_finished("status: ok")
        turn.append("They're healthy.")
        turn.finish
      end

      it "leaves prose, tool call, prose" do
        expect(segments.map(&:kind)).to eq(%w[text tool_call text])
      end

      it "keeps what was checked and what came back" do
        expect(segments.second.tool_call).to eq(
          "name" => "check_queues", "label" => "the job queues", "result" => "status: ok"
        )
      end
    end

    context "while the tool is still running" do
      before { turn.tool_started("check_queues", "the job queues") }

      it "has no result yet" do
        expect(segments.first.tool_result).to be_nil
      end
    end

    # Like a listing, a tool call puts no passages on the page.
    context "when the model checks something and then says nothing" do
      before do
        turn.tool_started("check_queues", "the job queues")
        turn.tool_finished("status: ok")
        turn.finish
      end

      it "says it finished without answering" do
        expect(turn.message.error).to eq("The model finished without answering.")
      end
    end
  end

  # Each segment is counted and timed against its own stream — see Chat::Pace
  # for why the provider's own token total is deliberately not used.
  describe "counting what was generated" do
    let(:outcome) { Retrieval::Outcome.new(hits: [], candidate_count: 0) }

    context "when the model reasons and then answers" do
      before do
        3.times { turn.append_thinking("Think. ") }
        2.times { turn.append("Ninety days. ") }
        turn.finish
      end

      it "counts each segment's own deltas" do
        expect(segments.map(&:token_count)).to eq([3, 2])
      end
    end

    # Both segments are prose, and each is counted from its own first delta —
    # so the seconds the search took land in neither of them.
    context "when the model searches mid-answer" do
      before do
        turn.append("Let me check.")
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(outcome)
        3.times { turn.append("Every 90 days. ") }
        turn.finish
      end

      it "counts each round of prose separately" do
        expect(segments.map(&:token_count)).to eq([1, nil, 3])
      end
    end

    # What a server that batches tokens into one event reports for each of them.
    context "when the deltas carry their own token counts" do
      before do
        turn.append("Every ", tokens: 3)
        turn.append("90 days. ", tokens: 4)
        turn.finish
      end

      it "counts tokens rather than deltas" do
        expect(segments.map(&:token_count)).to eq([7])
      end
    end

    # A delta nobody could count takes the whole segment's count with it: the
    # tokens behind it are in the text either way, so counting the rest would
    # report a confidently low rate. Chat::Responder decides when that happens.
    context "when a delta arrives uncounted" do
      before do
        turn.append("Every ", tokens: 3)
        turn.append("90 days. ", tokens: nil)
        turn.finish
      end

      it "leaves the segment unmeasured" do
        expect(segments.map(&:token_count)).to eq([nil])
      end
    end

    # Nothing was generated, so there is no rate to claim — not a rate of zero.
    context "when the turn only searched" do
      before do
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(outcome)
        turn.finish
      end

      it "leaves the retrieval segment unmeasured" do
        expect(segments.map(&:token_count)).to eq([nil])
      end
    end
  end

  describe "#note_context" do
    # A turn that searches is several requests, and each one's count already
    # covers the history the one before it counted. Summing them would report a
    # conversation as a multiple of its own size.
    context "when the model takes several rounds" do
      before do
        turn.append("Let me check.")
        turn.note_context(1_200)
        turn.note_context(4_800)
        turn.finish
      end

      it "records the largest prompt, not their total" do
        expect(turn.message.reload.input_tokens).to eq(4_800)
      end
    end

    context "when the server reports nothing" do
      before do
        turn.append("Ninety days.")
        turn.finish
      end

      it "leaves the turn unmeasured rather than claiming zero" do
        expect(turn.message.reload.input_tokens).to be_nil
      end
    end

    # The meter lives above the composer, outside the turn it was measured by,
    # so it can't ride the message replace.
    context "when the turn closes" do
      before do
        turn.append("Ninety days.")
        turn.note_context(4_800)
        turn.finish
      end

      it "pushes the context meter to the page" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, hash_including(target: "context_conversation_#{conversation.id}"))
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

    context "after a listing has returned but before the model speaks" do
      before do
        turn.listing_started
        turn.listing_finished(Retrieval::Listing.new(kind: :collections))
      end

      it "says it is reading what came back" do
        expect(turn.message.waiting_on).to eq("Reading the listing…")
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

    # The failure this catches in the wild: the model lists, works out its next
    # call in the analysis channel, and never makes it. A listing puts no
    # passages on the page, so the turn has answered nothing and must say so
    # rather than ending quietly with a panel and no reply.
    context "when the model listed but never wrote prose" do
      before do
        turn.listing_started
        turn.listing_finished(Retrieval::Listing.new(kind: :collections))
        turn.finish
      end

      it "says it finished without answering" do
        expect(turn.message.error).to eq("The model finished without answering.")
      end
    end
  end

  # Streaming replaces only the segment being written to; anything that adds or
  # closes a segment replaces the whole message. A segment-level replace can't
  # repaint the spinner above it, so getting this split wrong leaves a turn that
  # spins forever with prose underneath it.
  describe "broadcasting" do
    let(:message_target) { Views::Conversations::Message.dom_id(turn.message) }
    let(:live_segment) { segments.find(&:text?) }

    # Every append is due, so a delta that opens no segment still ticks.
    before do
      stub_const("Chat::Turn::BROADCAST_INTERVAL", 0)
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    end

    context "when a delta opens a text segment" do
      before { turn.append("Credentials rotate.") }

      it "replaces the whole message" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, hash_including(target: message_target))
      end
    end

    # The bug this replaced: a turn put on the page by a single append, which is
    # lost if it fires before the browser's subscription is up — there is no
    # replay, and every replace after it then aims at an element the page never
    # got. A replace carries the turn's whole state, so losing one costs nothing.
    context "over a whole turn" do
      before do
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(Retrieval::Outcome.new(hits: [], candidate_count: 0))
        turn.append("Every 90 days.")
        turn.finish
      end

      it "never appends anything" do
        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
      end
    end

    context "when a delta only extends the segment already open" do
      before do
        turn.append("Credentials ")
        turn.append("rotate every 90 days.")
      end

      it "replaces that segment" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, hash_including(target: Views::Conversations::Segment.dom_id(live_segment)))
      end
    end

    # The map Chat::Turn keeps from the search is what makes this possible
    # without walking every segment of the message on each tick.
    context "when prose extends a segment written after a search" do
      let(:conversation) { create(:conversation, :reaching_everything) }
      let(:document) { create(:document, title: "Credential Policy") }
      let(:chunk) { create(:chunk, document: document) }
      let(:outcome) do
        Retrieval::Outcome.new(
          hits: [Retrieval::Hit.new(chunk: chunk, document: document, distance: 0.1, score: 1.0, handle: 1)],
          candidate_count: 1
        )
      end

      before do
        turn.retrieval_started(["credential rotation"])
        turn.retrieval_finished(outcome)
        turn.append("Rotation is annual [1]")
        turn.append(" per policy.")
      end

      it "resolves the citation in the segment it broadcasts" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, hash_including(
            target: Views::Conversations::Segment.dom_id(live_segment),
            html: /href="\/documents\/#{document.id}#chunk_#{chunk.id}"/
          ))
      end
    end
  end

  # A tick stages the buffer in memory and only sometimes writes it. The page
  # must not be able to tell; a crash is the only thing that can.
  describe "writing while streaming" do
    let(:persisted) { Segment.find(segments.first.id).content }

    before do
      stub_const("Chat::Turn::BROADCAST_INTERVAL", 0)
      stub_const("Chat::Turn::WRITE_EVERY", 5)
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    end

    context "when deltas arrive between writes" do
      before do
        turn.append("Credentials ")
        turn.append("rotate ")
        turn.append("every 90 days.")
      end

      it "leaves the row behind the stream" do
        expect(persisted).to eq("Credentials ")
      end

      it "broadcasts the staged content anyway" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, hash_including(html: /rotate every 90 days\./))
      end
    end

    context "when the turn ends between writes" do
      before do
        turn.append("Credentials ")
        turn.append("rotate ")
        turn.append("every 90 days.")
        turn.finish
      end

      # The flush writes whatever the ticks didn't, so an orderly ending never
      # loses a word — only a crash can.
      it "writes everything the ticks skipped" do
        expect(persisted).to eq("Credentials rotate every 90 days.")
      end
    end

    context "when a search interrupts between writes" do
      let(:outcome) { Retrieval::Outcome.new(hits: [], candidate_count: 0) }

      before do
        turn.append("Let me ")
        turn.append("check.")
        turn.retrieval_started(["rotation"])
        turn.retrieval_finished(outcome)
      end

      # retrieval_started renders the message from the database, so staged
      # content has to reach the row before it does.
      it "writes the staged content before rendering from the row" do
        expect(persisted).to eq("Let me check.")
      end
    end

    # A thinking delta opens a segment, which renders the whole message from the
    # database — while the text segment above it holds staged content that no
    # tick has written yet.
    context "when reasoning interrupts prose between writes" do
      let(:persisted) { Segment.find(segments.find(&:text?).id).content }

      before do
        turn.append("Before ")
        turn.append("more ")
        turn.append_thinking("Reconsidering.")
      end

      it "writes the staged prose before rendering from the row" do
        expect(persisted).to eq("Before more ")
      end
    end

    # Once a write has happened, the segment compares against whatever object it
    # was handed. Hand it the live buffer rather than a copy and appending to that
    # buffer moves both sides of the comparison at once: the record stops looking
    # dirty, and every write after the first silently does nothing.
    context "when deltas keep arriving after a write" do
      before do
        stub_const("Chat::Turn::WRITE_EVERY", 2)
        turn.append("a ")
        turn.append("b ")
        turn.append("c ")
        turn.append("d ")
        turn.append("e")
        turn.finish
      end

      it "keeps writing what the stream adds" do
        expect(persisted).to eq("a b c d e")
      end
    end

    context "when every tick writes" do
      before do
        stub_const("Chat::Turn::WRITE_EVERY", 1)
        turn.append("Credentials ")
        turn.append("rotate.")
      end

      it "keeps the row current" do
        expect(persisted).to eq("Credentials rotate.")
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
  describe "#reading_started" do
    let(:document) { create(:document, title: "Security Handbook") }
    let(:chunk) { create(:chunk, document:, position: 9, content: "It rotates every 90 days.") }
    let(:reading) do
      Retrieval::Reading.new(
        document:, from: 10, to: 10, total: 47,
        hits: [Retrieval::Hit.new(chunk:, document:, handle: 1)]
      )
    end

    context "when the model reads mid-sentence" do
      before do
        turn.append("Let me look at that document.")
        turn.reading_started(document.id)
        turn.reading_finished(reading)
        turn.append("It rotates every 90 days.")
        turn.finish
      end

      # Same ordering rule as a search: the transcript records the pause where
      # it happened rather than tidying the read away.
      it "leaves prose, reading, prose" do
        expect(segments.map(&:kind)).to eq(%w[text reading text])
      end

      it "records which document and range it read" do
        expect(segments.second.range).to eq("chunk 10 of 47")
      end

      it "records the passage as a citable hit" do
        expect(segments.second.hits.map(&:handle)).to eq([1])
      end

      # Nothing ranked it, so there is no similarity to show.
      it "leaves the hit unranked" do
        expect(segments.second.hits.first.distance).to be_nil
      end

      # Chunks are renumbered by a reingest, so the position is snapshotted for
      # the same reason the snippet is.
      it "snapshots where in the document it came from" do
        expect(segments.second.hits.first.chunk_number).to eq(10)
      end
    end

    # A read that refused still happened, and a turn that shows nothing would
    # have the model asserting things with no visible provenance.
    context "when the read was refused" do
      before do
        turn.reading_started(999_999)
        turn.reading_finished(Retrieval::Reading.refused(:not_found))
        turn.finish
      end

      it "still leaves the segment in the transcript" do
        expect(segments.map(&:kind)).to eq(["reading"])
      end

      it "does not count as the turn saying nothing" do
        expect(turn.message.reload.error).to be_nil
      end
    end
  end

  # Handles number the whole turn. A map that reset on each block would resolve
  # a citation from the first search against the second search's hits.
  describe "handles across several rounds" do
    let(:document) { create(:document, title: "Security Handbook") }

    def outcome(handle)
      Retrieval::Outcome.new(
        hits: [Retrieval::Hit.new(chunk: create(:chunk, document:), document:, distance: 0.2, score: 0.1, handle:)],
        candidate_count: 3
      )
    end

    before do
      turn.retrieval_started(["first"])
      turn.retrieval_finished(outcome(1))
      turn.retrieval_started(["second"])
      turn.retrieval_finished(outcome(2))
      turn.append("Both say so [1][2].")
      turn.finish
    end

    it "keeps every round's hits resolvable" do
      expect(segments.flat_map { it.hits.map(&:handle) }).to eq([1, 2])
    end
  end
end
