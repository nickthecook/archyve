# frozen_string_literal: true

module Chat
  # A running guess at how much of the window the conversation occupies, so the
  # meter can move while a turn is still going.
  #
  # ## Why there is anything to guess
  #
  # The server reports the real figure once per request, in a usage chunk at the
  # end of it — so a turn that calls no tool says nothing at all until it is
  # over, which is exactly the minute somebody is watching the bar. Everything
  # here exists to fill that minute and is thrown away the moment the real
  # number lands. See Chat::Turn#complete!, which is where the invariant is
  # kept: an in-progress turn's input_tokens is this guess, a completed turn's
  # is the server's own count or nothing.
  #
  # ## What it adds up
  #
  # The last turn the server *did* measure is the baseline, and it is most of
  # the answer: the instructions, the tool schemas and the whole transcript up
  # to that point are inside it, and not one of them could be counted from here.
  # On top goes everything added since — that turn's own answer, which its
  # prompt could not have contained; the question being asked now; this turn's
  # prose; and each tool result as it returns.
  #
  # ## The rule is what replay will send, not what was produced
  #
  # Everything but the live stream is measured as `Segment#for_history` would
  # send it, because that *is* the next prompt. The consequence worth knowing is
  # that the model's reasoning costs nothing — it is dropped from replay, so
  # however much of it a model produces, none of it reaches a later prompt.
  # Charging for it is not a small error either: on a gpt-oss turn it put the
  # guess 80% above the figure the server went on to report.
  #
  # ## It is still a guess, and is drawn as one
  #
  # Measured on two-turn chats against gpt-oss:120b that searched in both turns,
  # the final guess landed within about 10% of the figure the server went on to
  # report: -11%, +10%, +8% over three runs. It misses in both directions, for
  # reasons that pull opposite ways: a tool result reaches the
  # model as JSON, with field names and titles around the passage that
  # `for_history` replays without, and tokens that never arrive as deltas (the
  # arguments of a tool call, the markers a model uses to switch channels) are
  # missing from Pace's counts — against which the prose a turn produces after
  # its last tool call is charged twice, once here and once in the next turn's
  # baseline. Characters-per-token is a rule of thumb for English prose and is
  # wrong for a table, for code, and for most other languages.
  #
  # Close enough to move a bar honestly, not close enough to print as a fact —
  # so the meter marks an in-progress reading with a tilde rather than
  # pretending. See Views::Conversations::ContextMeter.
  class Context
    # Four characters to the token is the usual rule of thumb. Being wrong here
    # costs nothing that the next usage chunk doesn't correct.
    CHARS_PER_TOKEN = 4

    attr_reader :tokens

    def initialize(conversation)
      @tokens = baseline(conversation)
    end

    # One streamed delta of *prose*, carrying whatever the server said it was
    # worth — the same count Chat::Pace is given for the same chunk. Reasoning
    # does not come through here; see the note above.
    def tick(tokens = 1)
      @tokens += tokens
    end

    # A tool has returned. What it costs is not what it printed but what replay
    # will send, which is the question Segment#for_history already answers.
    def absorb(segment)
      @tokens += estimate(segment&.for_history)
    end

    private

    # Everything already in the prompt that nothing here could have counted.
    #
    # Read once, when the turn opens, and never again: once this turn starts
    # writing its guess to the row, Conversation#context_turn would find *this*
    # turn and the baseline would fold in on itself.
    def baseline(conversation)
      measured = conversation.context_turn
      return 0 if measured.nil?

      measured.input_tokens + said_since(conversation, measured)
    end

    # Everything added to the prompt since that turn was measured.
    #
    # From the measured turn, only what it *said* — not what it searched. Its
    # figure is the prompt of its last round, and that round had already been
    # sent every tool result the turn produced; charging for them again put the
    # guess 45% over on a two-turn chat with a search in each. What genuinely
    # isn't in it is the answer that came back afterwards.
    #
    # Everything after it in full, searches included: a turn the server never
    # reported a figure for has nothing covering its tool results.
    def said_since(conversation, measured)
      estimate(measured.spoken) +
        conversation.messages.where(position: (measured.position + 1)..)
          .sum { estimate(it.history_content) }
    end

    def estimate(text) = (text.to_s.length / CHARS_PER_TOKEN.to_f).ceil
  end
end
