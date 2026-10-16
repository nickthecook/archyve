# frozen_string_literal: true

module Tools
  # What every tool the chat model is given has in common.
  #
  # ## The model names things it was shown, and nothing else
  #
  # The scope is bound from the conversation and is never a parameter: a model
  # that cannot name a collection cannot probe for one, cannot be talked into
  # naming one, and cannot leak the existence of one by guessing. What it *may*
  # name is a document id it was handed — and that resolves through Corpus, the
  # same filter a search draws on, so naming is not access. See Tools::Read for
  # why a refusal has to say as little as it does.
  #
  # ## Saying nothing is not the same as saying no
  #
  # A model handed an empty result will tell someone their archive doesn't
  # cover a topic. Every tool here distinguishes "ran and found nothing" from
  # "couldn't run", and says which — in the result, where the model is looking,
  # rather than only in the system prompt it read a thousand tokens ago.
  class Base < RubyLLM::Tool
    # observer, when given, is told when a tool starts and what it produced, so
    # the transcript can show the work happening rather than only its result.
    # Chat::Turn is the one that matters; each tool documents the pair it calls.
    def initialize(corpus:, handles:, observer: nil, max_rounds: nil)
      @corpus = corpus
      @handles = handles
      @observer = observer
      @max_rounds = max_rounds || default_max_rounds
      @rounds = 0
      super()
    end

    # Said on every listing result, and phrased as permission rather than
    # prohibition on purpose: a small model told only "these cannot be cited"
    # reads it as "these cannot be used" and goes quiet on a question the
    # listing just answered. What it must not do is write a handle — one that
    # writes [3] meaning "the third collection" produces a citation resolving to
    # whatever passage 3 happened to be, wrong and quietly.
    NOT_CITABLE = "Tell the user what this shows, in your own words. There are no passages here, " \
                  "so write no citation handles for these rows."

    # Every tool renders through here, so each one builds a plain hash and none
    # of them formats. See Tools::Reply for why the hash itself won't do.
    def call(args) = Reply.call(super)

    private

    attr_reader :corpus, :handles, :observer

    def scope_label = @corpus.label

    # Each tool keeps its own count against its own setting, so spending one
    # budget leaves the others whole — a model that has searched twice can
    # still read. Every tool must name the setting it draws on.
    def default_max_rounds
      raise NotImplementedError, "#{self.class} must say which round budget it spends"
    end

    # Counted here rather than handed to RubyLLM: its `calls:` option is about
    # how many tool calls a single response may contain, not how many rounds a
    # turn may take, and there is no round limit in the gem to lean on.
    def over_budget? = @rounds >= @max_rounds

    def spend_round = @rounds += 1

    # Refused rather than halted. Stopping the loop outright would cut the reply
    # off mid-sentence; telling the model its budget is gone leaves it to finish
    # with what it has, which is what someone reading the answer needs.
    def budget_spent(verb)
      {
        status: "budget_spent",
        instruction: "You have already #{verb} #{@max_rounds} #{'time'.pluralize(@max_rounds)} this turn " \
                     "and cannot again. Answer from what you already have, or say you couldn't find it " \
                     "— do not answer from your own knowledge."
      }
    end
  end
end
