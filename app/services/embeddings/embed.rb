module Embeddings
  # Produces embedding vectors via the corpus's embedding model. nomic is
  # asymmetric: text being indexed must be prefixed with "search_document:" and
  # a query with "search_query:", or retrieval quality drops and the two sides
  # stop lining up. Callers pick the side by method: `document` when embedding
  # chunks for storage, `query` when embedding a search.
  #
  # The prefixes live here, not on the InferenceModel row, because they are
  # inference semantics rather than configuration — a different embedder is not
  # only a different row, and pretending otherwise would hide that.
  #
  # Which model, and which host, come from InferenceModel.active_embedding.
  class Embed
    class DimensionMismatch < StandardError; end

    # Raised when nothing is configured to embed with. A fresh install has no
    # inference servers at all — nothing is seeded unless OLLAMA_API_BASE is set
    # — so this is an ordinary state to be in, and it gets an error that says so
    # rather than a NoMethodError on nil somewhere further down.
    class NotConfigured < StandardError; end

    PREFIXES = { search_document: "search_document: ", search_query: "search_query: " }.freeze

    def self.document(text) = new.call(text, task: :search_document)
    def self.query(text) = new.call(text, task: :search_query)

    # => Array<Float> of length model.dimensions
    def call(text, task:)
      model = active_model

      result = model.inference_server.llm_context.embed(
        "#{PREFIXES.fetch(task)}#{text}",
        model: model.name,
        provider: model.inference_server.ruby_llm_provider,
        assume_model_exists: true
      )
      vector = result.vectors
      ensure_dimensions!(vector, model)
      vector
    end

    private

    def active_model
      InferenceModel.active_embedding ||
        raise(NotConfigured, "no embedding model is configured — add one under Settings › Inference")
    end

    def ensure_dimensions!(vector, model)
      return if vector.is_a?(Array) && vector.size == model.dimensions

      raise DimensionMismatch,
        "expected #{model.dimensions}-dim vector from #{model.name} on #{model.inference_server.name}, " \
        "got #{vector&.size.inspect}"
    end
  end
end
