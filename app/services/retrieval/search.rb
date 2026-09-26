# frozen_string_literal: true

module Retrieval
  # Cosine-nearest chunks for one or more queries, narrowed to the corpus.
  #
  # **This is where access control is enforced for retrieval.** The search page
  # and the chat tool both come through here, and neither can widen what the
  # other sees: the filters come from Corpus, which is built from a user and a
  # bound scope, never from anything a caller passed in and never from anything
  # a model said. The chat tool can't name a collection because it is never
  # given one to name.
  #
  # Several queries fuse into one ranking (see Fuse) rather than being returned
  # separately, so the model gets one deduplicated, fairly-merged set instead of
  # stitching results together itself.
  class Search
    # How deep each query reaches before fusion. Wider than the number anyone
    # is shown: fusion needs enough of each list to tell agreement from noise,
    # and the pool size is itself reported as the "of 41" in the chat panel.
    CANDIDATES_PER_QUERY = 20

    # Most callers want a page of results; chat wants Setting.chat_result_limit.
    DEFAULT_LIMIT = 20

    def initialize(corpus:)
      @corpus = corpus
    end

    # queries: String or Array<String>. => Outcome
    def call(queries, limit: DEFAULT_LIMIT)
      queries = Array(queries).map { it.to_s.strip }.reject(&:blank?).uniq
      return Outcome.new if queries.empty?

      model = InferenceModel.active_embedding
      return Outcome.failed(:not_configured) if model.nil?

      # Marked between the two steps, not after them: embedding is the part that
      # talks to the server, and fusion is local SQL whose failures say nothing
      # about the host.
      candidates = candidates_for(queries, model)
      model.inference_server.mark_reachable!
      fuse(candidates, limit:)
    rescue StandardError => e
      Rails.logger.error("retrieval failed: #{e.class}: #{e.message}")
      model&.inference_server&.mark_unreachable!(e) if InferenceServer.unreachable_error?(e)
      Outcome.failed(:unreachable, server_name: model&.inference_server&.name, model_name: model&.name)
    end

    private

    def candidates_for(queries, model)
      queries.map { |query| nearest(query, model) }
    end

    def nearest(query, model)
      relation = Embedding.where(embedding_model: model.name)

      # Subqueries rather than plucked id lists, so a large archive stays in
      # SQL. Every filter is ANDed: readable *and* in scope.
      filters = @corpus.filters
      unless filters.empty?
        relation = relation.joins(chunk: :document)
        filters.each { |ids| relation = relation.where(documents: { id: ids }) }
      end

      relation
        .nearest_neighbors(:embedding, Embeddings::Embed.query(query), distance: "cosine")
        .includes(chunk: :document)
        .first(CANDIDATES_PER_QUERY)
    end

    def fuse(candidate_lists, limit:)
      Outcome.new(
        hits: Fuse.call(candidate_lists, limit:),
        candidate_count: candidate_lists.flatten.map(&:chunk_id).uniq.size
      )
    end
  end
end
