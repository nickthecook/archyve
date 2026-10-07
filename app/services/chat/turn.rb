# frozen_string_literal: true

module Chat
  # Builds one assistant turn as it happens, and pushes it to the browser.
  #
  # A turn is a sequence of segments, not a growing blob of text, because a
  # reply that searches genuinely is three things in order: prose, a search,
  # more prose. This class is what turns a stream of deltas and tool callbacks
  # back into that sequence — every time the model stops talking to search, the
  # current text segment is closed and a retrieval segment opens in its place.
  #
  # It is also the observer the tools report to, which is how a search or a read
  # appears in the transcript *while it runs* rather than only once it returns.
  class Turn
    # Streaming a token at a time would mean a broadcast per token. Rendering is
    # cheap but the cable isn't, so deltas accumulate and go out on a clock —
    # except at segment boundaries and at the end, which always flush, so the
    # last word of a turn is never left waiting for a tick that doesn't come.
    BROADCAST_INTERVAL = 0.1

    # Ticks per write. Every tick stages the buffer on the segment in memory —
    # that is what the broadcast renders from, so the page is never behind —
    # but only every Nth tick puts it in the database.
    #
    # The row is what a crash leaves behind, and what a page load reads. A
    # reader is barely affected: a browser arriving mid-turn renders content up
    # to N ticks old and the next broadcast corrects it within a tick. A crash
    # is the real cost — up to N ticks of prose lost from a turn that, having
    # crashed, never completed anyway.
    #
    # Worth it because the write is not the expensive part: `content` grows all
    # turn, and past ~2KB Postgres moves it out of line, so every tick
    # re-chunks the whole value into TOAST storage and orphans the last copy.
    # The bytes written across a turn go with the square of the tick count, so
    # the saving grows with the length of the answer.
    #
    # 1 writes on every tick, which is what this did before.
    WRITE_EVERY = [ENV.fetch("ARCHYVE_CHAT_WRITE_EVERY", "5").to_i, 1].max

    attr_reader :message

    # The message is opened by Chat::Ask, in the request that asked the
    # question, and this fills it in. That ordering is load-bearing rather than
    # tidy: it is what guarantees the page already has an element for this turn,
    # which is what lets everything below be a *replace*. See the note in
    # Chat::Ask for the race that made it so — and note that the spinner the
    # person sees while the model thinks is rendered by that page load, not by
    # anything here.
    def initialize(message)
      @message = message
      @conversation = message.conversation
      @buffer = +""
      @text_segment = nil
      @thinking_buffer = +""
      @thinking_segment = nil
      @broadcast_at = Time.current - BROADCAST_INTERVAL
      @hits = {}
      @ticks = 0
      # How fast each open segment is being generated, written to it when it
      # closes. See Chat::Pace.
      @text_pace = nil
      @thinking_pace = nil
    end

    # One streamed delta of prose.
    #
    # Empty, not blank. A delta of "\n\n" is blank by Rails' reckoning, and
    # skipping those silently deletes every paragraph break and list newline in
    # the answer — the model streams whitespace as its own chunks, so the prose
    # arrives as "…while the door is open:1.Open the battery compartment".
    def append(delta, tokens: 1)
      return if delta.nil? || delta.empty?

      @buffer << delta
      # Nothing to open a segment for until something that isn't whitespace has
      # arrived: Segment requires content, and " " doesn't count as present.
      return if @text_segment.nil? && @buffer.blank?

      # Created with the buffer already in it, not empty and filled in later: a
      # text segment with no text is a meaningless row, and Segment validates
      # that rather than tolerating it for the length of a stream.
      # Whatever the model was reasoning about, it has stopped and started
      # answering — the two never interleave, and leaving the thinking segment
      # open would let a later round's analysis join the first round's.
      # A flushed thinking segment and a newly created text one are both
      # changes a segment-level replace can't carry: the first rewrites an
      # element this tick isn't aiming at, the second needs an element that
      # isn't on the page yet. Either way the whole message goes. It is also
      # what repaints the spinner — Message#waiting_on stops saying
      # "Thinking…" exactly when this segment gains content.
      flushed = flush_thinking
      created = @text_segment.nil?
      @text_segment ||= create_segment(:text, content: @buffer.dup)
      @text_pace ||= Pace.new
      @text_pace.tick(tokens)
      return broadcast! if created || flushed

      broadcast if due?
    end

    # One streamed delta of the model's own reasoning, which arrives on its own
    # channel rather than in the answer (RubyLLM hands it to us as
    # `chunk.thinking`). Kept as its own segment kind so the transcript can show
    # it collapsed, and so it can be left out of history — see
    # Segment#for_history.
    def append_thinking(delta, tokens: 1)
      return if delta.nil? || delta.empty?

      @thinking_buffer << delta
      return if @thinking_segment.nil? && @thinking_buffer.blank?

      created = @thinking_segment.nil?
      @thinking_segment ||= create_segment(:thinking, content: @thinking_buffer.dup)
      @thinking_pace ||= Pace.new
      @thinking_pace.tick(tokens)
      return broadcast! if created

      broadcast if due?
    end

    # --- Tools::Base observer ------------------------------------------------

    # The model has stopped to search. Close whatever it was saying and open a
    # retrieval segment now, with the queries but no results — this is the state
    # the spinner renders, and it only exists if we write it before searching.
    def retrieval_started(queries)
      flush_text
      flush_thinking
      @retrieval_segment = create_segment(:retrieval, queries: queries)
      broadcast!
    end

    def retrieval_finished(outcome)
      @retrieval_segment&.record!(outcome)
      absorb(@retrieval_segment)
      broadcast!
    end

    # The model has stopped to read a document. The id is all that is known
    # before the read runs — the title comes back with it — so the panel that
    # opens here names nothing yet, which is what the spinner state renders.
    def reading_started(_document_id)
      flush_text
      flush_thinking
      @reading_segment = create_segment(:reading)
      broadcast!
    end

    def reading_finished(reading)
      @reading_segment&.record_reading!(reading)
      absorb(@reading_segment)
      broadcast!
    end

    # The model has stopped to walk the archive rather than search it. Nothing
    # is known before the listing runs — not even which of the two it is — so
    # the panel that opens here says only that it is looking.
    def listing_started
      flush_text
      flush_thinking
      @listing_segment = create_segment(:listing)
      broadcast!
    end

    # Nothing to absorb: a listing shows no passages, so it contributes no hits
    # to the turn's citation namespace. See Segment#sourced?.
    def listing_finished(listing)
      @listing_segment&.record_listing!(listing)
      broadcast!
    end

    # ------------------------------------------------------------------------

    def finish
      flush_text
      flush_thinking
      # A turn that ends having said nothing is indistinguishable, on the page,
      # from one still thinking — the spinner renders on "no content yet" and
      # would spin for good. Models do occasionally return an empty completion
      # after a tool result, so say so rather than leaving the page pretending.
      @message.update!(error: "The model finished without answering.") if said_nothing?
      complete!
      @message
    end

    # The turn couldn't happen, for a reason that isn't the model's to explain.
    # Recorded on the message rather than written into a text segment: an
    # unreachable server didn't *say* anything, and a transcript that pretends
    # otherwise is a transcript you can't trust.
    def fail!(error)
      flush_text
      flush_thinking
      @message.update!(error: error)
      complete!
      @message
    end

    private

    # Held for the streaming renders that follow. Cited resolves citation
    # handles against the segments above the prose, and left to work that out
    # itself it walks every segment of the message on every tick.
    #
    # Merged rather than replaced: handles run on across a whole turn, so a
    # search, a read and a second search all cite into one namespace, and prose
    # after the third can still cite the first. `includes(:document)` because
    # Chat::Prose asks each hit whether it is followable and for its title,
    # both of which reach through the association; without it the walk is gone
    # and a query per hit takes its place.
    def absorb(segment)
      @hits.merge!(segment&.hits&.includes(:document)&.index_by(&:handle) || {})
    end

    # Stops the page waiting. Every exit from a turn goes through here, so a
    # path that forgets it leaves a spinner running for good.
    def complete!
      @message.update!(completed_at: Time.current)
      broadcast!
    end

    def create_segment(kind, **attributes)
      @message.segments.create!(
        kind: kind, position: @message.next_segment_position, **attributes
      )
    end

    # Persist what's buffered and stop appending to that segment — the next
    # delta starts a new one, after the retrieval that interrupted it.
    def flush_text
      @text_segment&.update!(content: @buffer.dup, **pace_attributes(@text_pace))
      @text_segment = nil
      @text_pace = nil
      # Cleared even with no segment to write it to: what's left in that case is
      # whitespace the model emitted before saying anything, and carrying it
      # into the next segment would indent it for no reason.
      @buffer = +""
    end

    def flush_thinking
      flushed = @thinking_segment.present?
      @thinking_segment&.update!(content: @thinking_buffer.dup, **pace_attributes(@thinking_pace))
      @thinking_segment = nil
      @thinking_pace = nil
      @thinking_buffer = +""
      flushed
    end

    # Empty rather than zeroes when there is no pace, so a flush of a segment
    # nothing streamed into leaves its counters null — "never measured" — rather
    # than claiming it generated nothing in no time.
    def pace_attributes(pace) = pace&.attributes || {}

    def due? = Time.current - @broadcast_at >= BROADCAST_INTERVAL

    # A search or a read on its own counts as having said something: the panel
    # is visible, so the turn isn't a blank box even when no prose followed.
    #
    # Thinking does not count, and neither does a listing. A model that reasons
    # and then says nothing has failed to answer, and it is a failure worth
    # naming — mis-channelled replies look exactly like it, and so does a model
    # that lists, works out its next call in the analysis channel, and never
    # makes it. A listing puts no passages on the page to make up for the
    # silence; the turn simply stopped short.
    def said_nothing?
      @message.error.blank? &&
        @message.segments.reload.none? { it.sourced? || (it.text? && it.content.present?) }
    end

    def broadcast
      @broadcast_at = Time.current
      @ticks += 1
      stage(@text_segment, @buffer)
      stage(@thinking_segment, @thinking_buffer)
      write_staged if (@ticks % WRITE_EVERY).zero?
      broadcast_segment(@text_segment)
      broadcast_segment(@thinking_segment)
    end

    # In memory only. The view renders `segment.content`, the attribute, so a
    # staged buffer is enough to keep every broadcast current between writes.
    #
    # The .dup is belt and braces. Assignment keeps the object it is handed —
    # reads cast a fresh copy off it, which is why this is easy to miss — and
    # update_columns does no casting at all. A live buffer that reached
    # update_columns would become the value dirty tracking compares against,
    # and every write after it would look like a no-op. What actually closes
    # that door is write_segment passing `segment.content`, already a copy.
    def stage(segment, buffer)
      return if segment.nil?

      segment.content = buffer.dup
    end

    def write_staged
      write_segment(@text_segment)
      write_segment(@thinking_segment)
    end

    # update_columns, not update!: this runs throughout a stream, the content is
    # rewritten wholesale each time, and there is nothing to validate that
    # create! didn't already. Skipped entirely when nothing has been staged
    # since the last write, which is the case for a turn that has stopped
    # talking to search.
    def write_segment(segment)
      return if segment.nil? || !segment.content_changed?

      segment.update_columns(content: segment.content, updated_at: Time.current)
    end

    # One segment, to the element the page already has for it. Nothing else on
    # the turn can have changed: a tick only ever writes the buffers above, and
    # anything that adds or closes a segment goes through broadcast! instead.
    def broadcast_segment(segment)
      return if segment.nil?

      Turbo::StreamsChannel.broadcast_replace_to(
        @conversation,
        target: Views::Conversations::Segment.dom_id(segment),
        html: Views::Conversations::Segment.new(segment:, hits: @hits).call
      )
    end

    # The whole turn, for the changes a segment-level replace can't carry:
    # a segment that has just been added or closed, the spinner above them, the
    # error, the attribution. Every one of these is idempotent — it sends the
    # turn's entire current state — so a broadcast nobody was subscribed for
    # costs a render and nothing else.
    def broadcast!
      @broadcast_at = Time.current
      # This renders from the database, not from the segments held here, so
      # anything a tick staged and hasn't written yet would render stale.
      write_staged
      # Re-read with everything the render touches already in hand, rather than
      # #reload followed by a walk that lazy-loads its way down. The view renders
      # *every* segment each tick, and a retrieval segment asks each of its hits
      # for a document title — so left lazy that is a Hit query plus a Document
      # query per distinct document, per retrieval segment, per tick. The
      # writes a turn makes clear the query cache as it goes, so little of it is
      # ever served from cache: real round trips, for the length of a turn.
      @message = Message.includes(:inference_model, segments: { hits: :document }).find(@message.id)
      Turbo::StreamsChannel.broadcast_replace_to(
        @conversation,
        target: Views::Conversations::Message.dom_id(@message),
        html: Views::Conversations::Message.new(message: @message).call
      )
    end
  end
end
