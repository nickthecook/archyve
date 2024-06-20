class Embedder
  def initialize(embedding_model)
    @embedding_model = embedding_model
  end

  def embed(text)
    response = client.embed(text)

    response["embedding"]
  end

  private

  def client
    @client ||= LlmClients::Ollama.new(
      endpoint:,
      api_key: "todo",
      embedding_model: @embedding_model.model
    )
  end

  def endpoint
    ModelServer.active_server.url
  end
end
