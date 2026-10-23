# frozen_string_literal: true

module Tools
  # search this conversation's archive with multiple queries
  #
  # Each result carries two different kinds of name:
  # - `handle` cites the passage
  # - `id` addresses the document, so the model can call the read tool on the doc directly in a follow up
  class Search < Base
    params do
      array :queries,
        description: "Two to four differently-worded search phrases for the same question. " \
                     "Vary the vocabulary — documents rarely use the words a question does." \
                     "Only the first four queries are used; any beyond that are discarded." do
        string
      end
    end

    NAME = "search_archive"
    def name = NAME

    # tell the model what it's searching, so it knows the difference between "not in the archive" and
    # "not in the collections the user chose to search"
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
