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

    def initialize(conversation)
      @conversation = conversation
      @message = conversation.messages.create!(
        role: :assistant, position: conversation.next_message_position
      )
      @buffer = +""
      @text_segment = nil
      @broadcast_at = Time.current - BROADCAST_INTERVAL
    end

    # One streamed delta of prose.
    def append(delta)
      return if delta.blank?

      @buffer << delta
      # Created with the first delta already in it, not empty and filled in
      # later: a text segment with no text is a meaningless row, and Segment
      # validates that rather than tolerating it for the length of a stream.
      @text_segment ||= create_segment(:text, content: @buffer.dup)
      broadcast if due?
    end

    # --- Retrieval::Tool observer -------------------------------------------

    # The model has stopped to search. Close whatever it was saying and open a
    # retrieval segment now, with the queries but no results — this is the state
    # the spinner renders, and it only exists if we write it before searching.
    def retrieval_started(queries)
      flush_text
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
      broadcast!
      @message
    end

    # The turn couldn't happen, for a reason that isn't the model's to explain.
    # Recorded on the message rather than written into a text segment: an
    # unreachable server didn't *say* anything, and a transcript that pretends
    # otherwise is a transcript you can't trust.
    def fail!(error)
      flush_text
      @message.update!(error: error)
      broadcast!
      @message
    end

    private

    def create_segment(kind, **attributes)
      @message.segments.create!(
        kind: kind, position: @message.next_segment_position, **attributes
      )
    end

    # Persist what's buffered and stop appending to that segment — the next
    # delta starts a new one, after the retrieval that interrupted it.
    def flush_text
      return if @text_segment.nil?

      @text_segment.update!(content: @buffer.dup)
      @text_segment = nil
      @buffer = +""
    end

    def due? = Time.current - @broadcast_at >= BROADCAST_INTERVAL

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
      broadcast!
    end

    def broadcast!
      @broadcast_at = Time.current
      @message.reload
      Turbo::StreamsChannel.broadcast_replace_to(
        @conversation,
        target: Views::Chat::Turn.dom_id(@message),
        html: Views::Chat::Turn.new(message: @message).call
      )
    end
  end
end
