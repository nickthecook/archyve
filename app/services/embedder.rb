class Embedder
  def initialize(embedding_model, traceable: nil)
    @embedding_model = embedding_model
    @traceable = traceable
  end

  def embed(text)
    response = client.embed(text)

    response["embedding"]
  end

  private

  def client
    @client ||= LlmClients::Ollama::Client.new(
      endpoint:,
      api_key: "todo",
      embedding_model: @embedding_model.model,
      traceable: @traceable
    )
  end

  def endpoint
    ModelServer.active_server.url
  end
end
