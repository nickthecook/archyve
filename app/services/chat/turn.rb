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
  # It is also the observer Retrieval::Tool reports to, which is how the search
  # appears in the transcript *while it runs* rather than only once it returns.
  class Turn
    # Streaming a token at a time would mean a broadcast per token. Rendering is
    # cheap but the cable isn't, so deltas accumulate and go out on a clock —
    # except at segment boundaries and at the end, which always flush, so the
    # last word of a turn is never left waiting for a tick that doesn't come.
    BROADCAST_INTERVAL = 0.1

    attr_reader :message

    def initialize(conversation, model: nil)
      @conversation = conversation
      @message = conversation.messages.create!(
        role: :assistant, position: conversation.next_message_position, inference_model: model
      )
      @buffer = +""
      @text_segment = nil
      @thinking_buffer = +""
      @thinking_segment = nil
      @broadcast_at = Time.current - BROADCAST_INTERVAL
      @on_page = false
      # Immediately, before a single token exists. A replace can only land on an
      # element that is already in the DOM, and the page was rendered before
      # this message existed — so the turn has to be *appended* once first, or
      # every broadcast for it goes nowhere and the page just sits there.
      #
      # Doing it here rather than on the first delta also means the spinner
      # shows while the model is still thinking, which is the whole gap it
      # exists to cover.
      broadcast!
    end

    # One streamed delta of prose.
    #
    # Empty, not blank. A delta of "\n\n" is blank by Rails' reckoning, and
    # skipping those silently deletes every paragraph break and list newline in
    # the answer — the model streams whitespace as its own chunks, so the prose
    # arrives as "…while the door is open:1.Open the battery compartment".
    def append(delta)
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
      flush_thinking
      @text_segment ||= create_segment(:text, content: @buffer.dup)
      broadcast if due?
    end

    # One streamed delta of the model's own reasoning, which arrives on its own
    # channel rather than in the answer (RubyLLM hands it to us as
    # `chunk.thinking`). Kept as its own segment kind so the transcript can show
    # it collapsed, and so it can be left out of history — see
    # Segment#for_history.
    def append_thinking(delta)
      return if delta.nil? || delta.empty?

      @thinking_buffer << delta
      return if @thinking_segment.nil? && @thinking_buffer.blank?

      @thinking_segment ||= create_segment(:thinking, content: @thinking_buffer.dup)
      broadcast if due?
    end

    # --- Retrieval::Tool observer -------------------------------------------

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
      @text_segment&.update!(content: @buffer.dup)
      @text_segment = nil
      # Cleared even with no segment to write it to: what's left in that case is
      # whitespace the model emitted before saying anything, and carrying it
      # into the next segment would indent it for no reason.
      @buffer = +""
    end

    def flush_thinking
      @thinking_segment&.update!(content: @thinking_buffer.dup)
      @thinking_segment = nil
      @thinking_buffer = +""
    end

    def due? = Time.current - @broadcast_at >= BROADCAST_INTERVAL

    # A search on its own counts as having said something: the retrieval panel
    # is visible, so the turn isn't a blank box even when no prose followed.
    #
    # Thinking does not count. A model that reasons and then says nothing has
    # failed to answer, and it is a failure worth naming — mis-channelled
    # replies, where the whole reply arrives as analysis, look exactly like it.
    def said_nothing?
      @message.error.blank? &&
        @message.segments.reload.none? { it.retrieval? || (it.text? && it.content.present?) }
    end

    def broadcast
      # update_columns, not update!: this runs on every tick of a stream, the
      # content is rewritten wholesale each time, and there is nothing to
      # validate that create! didn't already.
      #
      # .dup matters. Handing the live buffer to an attribute and then appending
      # to it mutates the value ActiveRecord diffs against, so the record stops
      # looking dirty and the final write silently does nothing — the turn ends
      # holding whatever was in the buffer at the last broadcast.
      @text_segment&.update_columns(content: @buffer.dup, updated_at: Time.current)
      @thinking_segment&.update_columns(content: @thinking_buffer.dup, updated_at: Time.current)
      broadcast!
    end

    # Append once to put the turn on the page, replace it thereafter. The
    # append is what a Turbo `replace` cannot do — create an element that isn't
    # there — and the replace is what keeps the rest of the transcript from
    # being re-rendered on every tick of the stream.
    def broadcast!
      @broadcast_at = Time.current
      # Re-read with everything the render touches already in hand, rather than
      # #reload followed by a walk that lazy-loads its way down. The view renders
      # *every* segment each tick, and a retrieval segment asks each of its hits
      # for a document title — so left lazy that is a Hit query plus a Document
      # query per distinct document, per retrieval segment, per tick. The
      # update_columns in #broadcast clears the query cache immediately before, so
      # none of it is ever served from cache: real round trips, ten times a second,
      # for the length of a turn.
      @message = Message.includes(:inference_model, segments: { hits: :document }).find(@message.id)
      html = Views::Conversations::Message.new(message: @message).call

      if @on_page
        Turbo::StreamsChannel.broadcast_replace_to(
          @conversation, target: Views::Conversations::Message.dom_id(@message), html: html
        )
      else
        Turbo::StreamsChannel.broadcast_append_to(
          @conversation, target: Views::Conversations::Message.thread_dom_id(@conversation), html: html
        )
        @on_page = true
      end
    end
  end
end
