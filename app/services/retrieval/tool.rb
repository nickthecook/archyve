# frozen_string_literal: true

module Retrieval
  # The one tool the chat model is given: search this conversation's archive.
  #
  # ## The model never names a collection
  #
  # The scope is bound here, from the conversation, and is not a parameter. That
  # is a security property, not a convenience: a model that cannot name a
  # collection cannot probe for one, cannot be talked into naming one, and
  # cannot leak the existence of a collection by guessing at it. The only thing
  # it decides is what to *ask*.
  #
  # It gets one call with several queries rather than several calls with one,
  # because merging is Archyve's job and doing it here means one embedding pass,
  # one fused ranking, and no chance for the model to lose track halfway through
  # stitching results together itself.
  #
  # ## Saying nothing is not the same as saying no
  #
  # A model handed an empty list will tell someone their archive doesn't cover a
  # topic. So an unreachable embedding server must not come back looking empty:
  # `:unavailable` says retrieval broke and tells the model, in the result, not
  # to fall back on what it happens to know. See Retrieval::Outcome.
  class Tool < RubyLLM::Tool
    # More than a handful of queries is a model flailing, not a model being
    # thorough — and each one is an embedding call and a vector scan. Extra
    # queries are dropped rather than refused: a truncated search is a better
    # answer than an error the model has to recover from.
    MAX_QUERIES = 4

    params do
      array :queries,
        description: "Two to four differently-worded search phrases for the same question. " \
                     "Vary the vocabulary — documents rarely use the words a question does." do
        string
      end
    end

    # Named for the model, not derived from the class: this string is part of
    # the prompt, and RubyLLM's default would hand it "tool".
    def name = "search_archive"

    # Instance-level, unlike RubyLLM's class-level `description`, so the model
    # is told what it is searching. Without this it will report that the archive
    # lacks something when the truth is the user narrowed the scope to one
    # document.
    def description
      <<~TEXT.strip
        Search #{@scope_label} for passages relevant to the question. You cannot read
        these documents any other way, so use this whenever an answer might depend on
        what they say. You cannot choose which documents are searched — the scope is
        chosen by the user.
      TEXT
    end

    # observer, when given, is told when a search starts and what it found, so
    # the transcript can show the search happening rather than only its result.
    # It responds to #retrieval_started(queries) and #retrieval_finished(outcome).
    def initialize(user:, scope: nil, scope_label: "your archive", limit: nil, max_rounds: nil, observer: nil)
      @user = user
      @scope = scope
      @scope_label = scope_label
      @limit = limit || Setting.chat_result_limit
      @max_rounds = max_rounds || Setting.chat_max_tool_rounds
      @rounds = 0
      @observer = observer
      super()
    end

    def execute(queries:)
      queries = Array(queries).filter_map { it.to_s.strip.presence }.uniq.first(MAX_QUERIES)
      return no_queries if queries.empty?
      return budget_spent if @rounds >= @max_rounds

      @rounds += 1
      @observer&.retrieval_started(queries)
      outcome = Search.new(user: @user, scope: @scope).call(queries, limit: @limit)
      @observer&.retrieval_finished(outcome)

      respond(outcome)
    end

    private

    # An argument problem, not a retrieval outcome — so nothing is recorded and
    # the model is told what to fix rather than told the archive is empty.
    def no_queries
      { error: "No queries given. Call search_archive again with at least one search phrase." }
    end

    # The guard against a model searching in circles. Counted here rather than
    # handed to RubyLLM: its `calls:` option is about how many tool calls a
    # single response may contain, not how many rounds a turn may take, and
    # there is no round limit in the gem to lean on.
    #
    # Refused rather than halted. Stopping the loop outright would cut the reply
    # off mid-sentence; telling the model its budget is gone leaves it to finish
    # with what it has, which is what someone reading the answer needs.
    def budget_spent
      {
        status: "budget_spent",
        instruction: "You have already searched #{@max_rounds} #{'time'.pluralize(@max_rounds)} this turn " \
                     "and cannot search again. Answer from the results you already have, or say you " \
                     "couldn't find it — do not answer from your own knowledge."
      }
    end

    def respond(outcome)
      return unavailable(outcome.failure) if outcome.failed?
      return no_matches if outcome.found_nothing?

      { status: "ok", scope: @scope_label, results: outcome.hits.map { result_for(it) } }
    end

    def result_for(hit)
      {
        handle: hit.handle,
        document: hit.document.title,
        section: hit.heading_path.presence,
        text: hit.chunk.content
      }.compact
    end

    # The wording matters more here than anywhere else in this class: it is the
    # difference between the model saying "your archive doesn't mention Stripe"
    # and "I couldn't search your archive". Only one of those is honest when the
    # embedding server is down.
    def unavailable(failure)
      {
        status: "unavailable",
        reason: failure.kind.to_s,
        instruction: "The archive could not be searched, so you have no sources. Tell the user " \
                     "retrieval is unavailable and do not answer from your own knowledge."
      }
    end

    def no_matches
      {
        status: "no_matches",
        scope: @scope_label,
        instruction: "The search ran and found nothing in #{@scope_label}. Say so, and say what " \
                     "was searched — do not answer from your own knowledge."
      }
    end
  end
end
