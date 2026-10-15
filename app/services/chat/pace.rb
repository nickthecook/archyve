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
  # InferenceServers::OpenAI#stream_params), one token where the server is
  # Ollama, and nothing at all otherwise.
  #
  # Nothing at all is the case worth knowing about. An OpenAI-compatible server
  # Archyve has no counts from could be batching or not, and there is no way to
  # tell from the stream — so the segment reports no rate rather than a number
  # that might be a third of the truth.
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
      @counted = true
      @first_at = nil
      @last_at = nil
    end

    # One delta, on either channel, for the segment this is following. A nil
    # count is a delta nobody could count — see #counted?.
    def tick(tokens = 1)
      now = Time.current
      @first_at ||= now
      @last_at = now
      tokens.nil? ? @counted = false : @tokens += tokens
    end

    # What Segment stores. Named for the columns so the caller reads as a write
    # rather than as arithmetic. The span is kept either way: how long the
    # segment took is known even when how much it generated isn't.
    def attributes = { token_count: counted? ? tokens : nil, generation_ms: elapsed_ms }

    private

    # Whether every delta came with a count. One that didn't leaves the whole
    # segment uncountable rather than undercounted: the tokens behind it are
    # still in the text, so adding up the rest reports a confidently low rate.
    # Segment#tokens_per_second shows nothing for a nil count, which is the
    # point — see Chat::Responder for where a missing count comes from.
    def counted? = @counted

    # Zero for a segment that saw a single delta: there is no span to divide by,
    # whatever that delta was worth. Segment#tokens_per_second reads that as "no
    # rate" rather than as infinity.
    def elapsed_ms
      return 0 if @first_at.nil?

      ((@last_at - @first_at) * 1000).round
    end
  end
end
