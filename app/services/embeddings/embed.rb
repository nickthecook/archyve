module Embeddings
  # Produces embedding vectors via the corpus-wide model (nomic-embed-text) over
  # Ollama. nomic is asymmetric: text being indexed must be prefixed with
  # "search_document:" and a query with "search_query:", or retrieval quality
  # drops and the two sides stop lining up. Callers pick the side by method:
  # `document` when embedding chunks for storage, `query` when embedding a search.
  class Embed
    class DimensionMismatch < StandardError; end

    MODEL = Embedding::DEFAULT_MODEL
    PROVIDER = :ollama
    PREFIXES = { search_document: "search_document: ", search_query: "search_query: " }.freeze

    def self.document(text) = new.call(text, task: :search_document)
    def self.query(text) = new.call(text, task: :search_query)

    # => Array<Float> of length Embedding::DIMENSIONS
    def call(text, task:)
      result = RubyLLM.embed(
        "#{PREFIXES.fetch(task)}#{text}",
        model: MODEL,
        provider: PROVIDER,
        assume_model_exists: true
      )
      vector = result.vectors
      ensure_dimensions!(vector)
      vector
    end

    private

    def ensure_dimensions!(vector)
      return if vector.is_a?(Array) && vector.size == Embedding::DIMENSIONS

      raise DimensionMismatch,
        "expected #{Embedding::DIMENSIONS}-dim vector from #{MODEL}, got #{vector&.size.inspect}"
    end
  end
end
