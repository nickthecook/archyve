class HomeController < ApplicationController
  def index
    render Views::Home::Index.new(stats: stats)
  end

  private

  def stats
    {
      collections: Collection.count,
      documents: Document.count,
      chunks: Chunk.count,
      embedding_model: Embedding::DEFAULT_MODEL,
      host: URI(ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/v1")).host,
      last_chat: nil
    }
  end
end
