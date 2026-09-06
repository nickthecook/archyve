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

  # Cosine-nearest chunks for the query, optionally narrowed to the scope's
  # documents. Embedding the query hits Ollama over the network, so a failure
  # degrades to a friendly message rather than a 500.
  def retrieve(query)
    vector = Embeddings::Embed.query(query)
    relation = Embedding.where(embedding_model: Embedding::DEFAULT_MODEL)
    relation = relation.joins(chunk: :document).where(documents: { id: @scope.document_ids }) if @scope
    relation
      .nearest_neighbors(:embedding, vector, distance: "cosine")
      .includes(chunk: :document)
      .first(RESULT_LIMIT)
  rescue StandardError => e
    Rails.logger.error("search failed: #{e.class}: #{e.message}")
    @error = "Couldn't reach the embedding model. Check that Ollama is running and #{Embedding::DEFAULT_MODEL} is pulled."
    []
  end

  # Turn the URL (c[] collection slugs, doc id) into a Scope, or nil for All.
  def resolve_scope
    doc_id = params[:doc].presence
    slugs = Array(params[:c]).reject(&:blank?)

    if doc_id
      document = Document.find_by(id: doc_id)
      Scope.new(label: document&.title || "one document", document_ids: [doc_id], hidden_params: { "doc" => doc_id })
    elsif slugs.any?
      collections = Collection.where(slug: slugs).to_a
      document_ids = CollectionMembership.active.where(collection: collections).distinct.pluck(:document_id)
      label = collections.map(&:name).to_sentence.presence || "these collections"
      Scope.new(label:, document_ids:, hidden_params: { "c" => collections.map(&:slug) })
    end
  end
end
