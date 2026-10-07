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
  # ## A delta is not always a token
  #
  # Ollama streams one token per event, so counting events was right for it.
  # vLLM flushes on a ~55ms clock with however many tokens it generated in
  # between — two to four of them at 60 tok/s — and counting *those* events
  # reports every model on that host at a steady ~18. So a tick carries a
  # count: the server's own figure for that chunk where it sends one (see
  # InferenceServers::OpenAI#stream_params), and one token otherwise.
  #
  # ## Counted per chunk, not from the response total
  #
  # The server reports its own output tokens when the response ends, and that
  # total deliberately isn't used. It covers tokens we never see as deltas: the
  # markers that switch the model between its analysis and final channels, and
  # the JSON arguments of a tool call, which RubyLLM hands over as one chunk
  # however many tokens went into it.
  #
  # Splitting a response's total across its segments in proportion to the
  # deltas each saw was tried and is worse than useless: on a response that ends
  # in a search, most of the unseen tokens are the tool call, and handing those
  # to the reasoning above it reported gpt-oss at 238 tok/s on a box that
  # streams a steady 61. Counting each segment against its own span is
  # consistent instead, because the tokens we can't see are at the boundaries
  # *between* segments.
  class Pace
    attr_reader :tokens

    def initialize
      @tokens = 0
      @first_at = nil
      @last_at = nil
    end

    # One delta, on either channel, for the segment this is following.
    def tick(tokens = 1)
      now = Time.current
      @first_at ||= now
      @last_at = now
      @tokens += tokens
    end

    # What Segment stores. Named for the columns so the caller reads as a write
    # rather than as arithmetic.
    def attributes = { token_count: tokens, generation_ms: elapsed_ms }

    private

    # Zero for a segment that saw a single delta: there is no span to divide by,
    # whatever that delta was worth. Segment#tokens_per_second reads that as "no
    # rate" rather than as infinity.
    def elapsed_ms
      return 0 if @first_at.nil?

      ((@last_at - @first_at) * 1000).round
    end
  end
end
