class SearchController < ApplicationController
  RESULT_LIMIT = 20

  def index
    @query = params[:q].to_s.strip
    @results = @query.present? ? retrieve(@query) : []
    render Views::Search::Index.new(query: @query, results: @results, error: @error)
  end

  private

  # Global RAG retrieval: embed the query, then cosine-nearest chunks across the
  # whole corpus. Collection scoping and access control come with auth later.
  def retrieve(query)
    vector = Embeddings::Embed.query(query)
    Embedding
      .where(embedding_model: Embedding::DEFAULT_MODEL)
      .nearest_neighbors(:embedding, vector, distance: "cosine")
      .includes(chunk: :document)
      .first(RESULT_LIMIT)
  rescue StandardError => e
    # Embedding the query hits Ollama over the network; a search should degrade
    # to a friendly message, never a 500.
    Rails.logger.error("search failed: #{e.class}: #{e.message}")
    @error = "Couldn't reach the embedding model. Check that Ollama is running and #{Embedding::DEFAULT_MODEL} is pulled."
    []
  end
end
