# frozen_string_literal: true

module Chat
  # How fast one segment was generated, counted as it streams.
  #
  # ## The span starts at the first delta
  #
  # Not at the request. The wait before the first token is the model reading the
  # prompt, and a conversation with twenty turns of history behind it spends
  # seconds there — folding that in would report a fast model as a slow one, and
  # would report the same model as slower the longer you talked to it.
  #
  # ## Deltas, not the provider's token count
  #
  # The server reports its own output tokens at the end of each response, and
  # that number deliberately isn't used here. It counts the whole response,
  # including the tokens we never see: the markers that switch the model between
  # its analysis and final channels, and the JSON arguments of a tool call —
  # which RubyLLM hands over as one chunk however many tokens went into it, so
  # there is no way to split them back out.
  #
  # Dividing a response's total across its segments in proportion to the deltas
  # each saw was tried, and it is worse than useless: on a response that ends in
  # a search, most of the unseen tokens are the tool call, and handing those to
  # the reasoning above it reported gpt-oss at 238 tok/s on a box that streams a
  # steady 61.
  #
  # Counting deltas against each segment's own span is consistent instead,
  # because the tokens we can't see are at the boundaries *between* segments —
  # inside one, deltas arrive at exactly the rate the model generates. Measured
  # against that same box, this reports 60.7 and 60.9 where the stream's
  # inter-delta gap says 61.
  class Pace
    attr_reader :tokens

    def initialize
      @tokens = 0
      @first_at = nil
      @last_at = nil
    end

    # One delta, on either channel, for the segment this is following.
    def tick
      now = Time.current
      @first_at ||= now
      @last_at = now
      @tokens += 1
    end

    # What Segment stores. Named for the columns so the caller reads as a write
    # rather than as arithmetic.
    def attributes = { token_count: tokens, generation_ms: elapsed_ms }

    private

    # Zero for a segment that saw a single delta: one token is a count, not a
    # rate, and there is no span to divide it by. Segment#tokens_per_second
    # reads that as "no rate" rather than as infinity.
    def elapsed_ms
      return 0 if @first_at.nil?

      ((@last_at - @first_at) * 1000).round
    end
  end
end
