class SearchController < ApplicationController
  RESULT_LIMIT = 20

  # A resolved search scope: what the query targets. `document_ids` narrows
  # retrieval; `label` names the scope in the UI; `hidden_params` re-emits the
  # scope as form fields so a follow-up query stays scoped. `nil` means All.
  # See the c[]/doc wire format in the scope-encoding notes.
  Scope = Data.define(:label, :document_ids, :hidden_params)

  def index
    @query = params[:q].to_s.strip
    @scope = resolve_scope
    @results = @query.present? ? retrieve(@query) : []
    render Views::Search::Index.new(query: @query, results: @results, error: @error, scope: @scope)
  end

  private

  # Cosine-nearest chunks for the query, narrowed by two independent filters:
  # what this person may read at all, and what they asked to search. Both are
  # subqueries rather than plucked id lists, so a large archive stays in SQL.
  #
  # This is where access control is enforced for retrieval — the chat tool will
  # come through the same path. Embedding the query hits Ollama over the
  # network, so a failure degrades to a friendly message rather than a 500.
  def retrieve(query)
    model = InferenceModel.active_embedding
    return no_embedding_model if model.nil?

    vector = Embeddings::Embed.query(query)
    relation = Embedding.where(embedding_model: model.name)

    filters = [retrievable_document_ids, @scope&.document_ids].compact
    unless filters.empty?
      relation = relation.joins(chunk: :document)
      filters.each { |ids| relation = relation.where(documents: { id: ids }) }
    end

    relation
      .nearest_neighbors(:embedding, vector, distance: "cosine")
      .includes(chunk: :document)
      .first(RESULT_LIMIT)
  rescue StandardError => e
    Rails.logger.error("search failed: #{e.class}: #{e.message}")
    @error = "Couldn't reach #{model&.inference_server&.name || 'the embedding model'}. " \
             "Check that it's running and #{model&.name} is pulled."
    []
  end

  # Not the same failure as an unreachable host, so not the same message: there
  # is nothing to reach yet. Only admins can fix it, so only they are told how.
  def no_embedding_model
    @error = if Current.user.admin?
      "No embedding model is configured. Add one under Settings › Inference."
    else
      "Search isn't available yet — no embedding model is configured."
    end
    []
  end

  # What this query may draw on, as a subquery; nil means unrestricted.
  #
  # Document.retrievable_by is strictly collection-based, deliberately narrower
  # than .reachable_by: a document in no collection is in nobody's corpus, even
  # though an operator can open it from /unsorted to file it.
  def retrievable_document_ids
    return nil if Current.user.admin?

    Document.retrievable_by(Current.user).select(:id)
  end

  # Turn the URL (c[] collection slugs, doc id) into a Scope, or nil for All.
  #
  # Slugs naming a collection this person can't read are dropped rather than
  # rejected: erroring would confirm the collection exists. A `doc` they can't
  # read is kept as an id but never resolves to a title, and intersects with the
  # readable filter above to nothing.
  def resolve_scope
    doc_id = params[:doc].presence
    slugs = Array(params[:c]).reject(&:blank?)

    if doc_id
      document = readable_documents.find_by(id: doc_id)
      Scope.new(label: document&.title || "one document", document_ids: [doc_id], hidden_params: { "doc" => doc_id })
    elsif slugs.any?
      collections = Collection.readable_by(Current.user).where(slug: slugs).to_a
      document_ids = CollectionMembership.active.where(collection: collections).distinct.pluck(:document_id)
      label = collections.map(&:name).to_sentence.presence || "these collections"
      Scope.new(label:, document_ids:, hidden_params: { "c" => collections.map(&:slug) })
    end
  end

  def readable_documents
    Document.retrievable_by(Current.user)
  end
end
