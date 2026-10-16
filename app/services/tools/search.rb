# frozen_string_literal: true

module Tools
  # Search this conversation's archive. The first tool the model reaches for,
  # and usually the one that finds what it needs.
  #
  # The scope is bound, not chosen — see Tools::Base. The only thing this tool
  # decides is what to *ask*, and it gets one call with several queries rather
  # than several calls with one, because merging is Archyve's job: one embedding
  # pass, one fused ranking, and no chance for the model to lose track halfway
  # through stitching results together itself.
  #
  # ## What a result names
  #
  # Each result carries two different kinds of name, and they are not
  # interchangeable. `handle` cites the passage; `id` addresses the document, so
  # the model can read around a chunk that was nearly enough with Tools::Read.
  class Search < Base
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
    # the prompt, and RubyLLM's default would hand it "search".
    def name = "search_archive"

    # Instance-level, unlike RubyLLM's class-level `description`, so the model
    # is told what it is searching. Without this it will report that the archive
    # lacks something when the truth is the user narrowed the scope to one
    # document.
    def description
      <<~TEXT.strip
        Search #{scope_label} for passages relevant to the question. Use this whenever an
        answer might depend on what those documents say. You cannot choose which documents
        are searched — the scope is chosen by the user. Each result carries the id of the
        document it came from, which read_document takes to show you more of it.
      TEXT
    end

    def initialize(limit: nil, **)
      super(**)
      @limit = limit || Setting.chat_result_limit
    end

    def execute(queries:)
      queries = Array(queries).filter_map { it.to_s.strip.presence }.uniq.first(MAX_QUERIES)
      return no_queries if queries.empty?
      return budget_spent("searched") if over_budget?

      spend_round
      observer&.retrieval_started(queries)
      outcome = handled(Retrieval::Search.new(corpus:).call(queries, limit: @limit))
      observer&.retrieval_finished(outcome)

      respond(outcome)
    end

    private

    def default_max_rounds = Setting.chat_max_search_rounds

    # Fuse numbers its own ranking 1..n, which is what the search page wants.
    # A turn wants one namespace across every search and read in it, so the
    # handles are re-stamped here — before the observer sees the outcome, so the
    # transcript and the model are citing the same numbers.
    def handled(outcome)
      return outcome if outcome.failed?

      outcome.with(hits: handles.assign(outcome.hits))
    end

    # An argument problem, not a retrieval outcome — so nothing is recorded and
    # the model is told what to fix rather than told the archive is empty.
    def no_queries
      { error: "No queries given. Call search_archive again with at least one search phrase." }
    end

    def respond(outcome)
      return unavailable(outcome.failure) if outcome.failed?
      return no_matches if outcome.found_nothing?

      { status: "ok", scope: scope_label, passages: passages_for(outcome.hits) }
    end

    def passages_for(hits)
      totals = chunk_totals(hits)
      hits.map { passage_for(it, totals) }
    end

    def passage_for(hit, totals)
      {
        handle: hit.handle,
        id: hit.document.id,
        document: hit.document.title,
        section: hit.heading_path.presence,
        # 1-based, matching what documents#show calls the same chunk. The model
        # is told where this passage sits and how much document surrounds it,
        # which is what it needs to ask read_document for a sensible range.
        chunk: hit.chunk.position + 1,
        chunks: totals[hit.document.id],
        text: hit.chunk.content
      }.compact
    end

    # One query for the whole result set. Asking each document for its own
    # count is a query per hit, every search, for a number that is only there to
    # tell the model how far it can page.
    def chunk_totals(hits)
      Chunk.where(document_id: hits.map { it.document.id }.uniq).group(:document_id).count
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
        scope: scope_label,
        instruction: "The search ran and found nothing in #{scope_label}. Say so, and say what " \
                     "was searched — do not answer from your own knowledge."
      }
    end
  end
end
