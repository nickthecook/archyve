class Embedder
  def embed(text)
    response = client.embed(text)

    response["embedding"]
  end

  private

  def client
    @client ||= LlmClients::Ollama.new(
      endpoint:,
      api_key: "todo"
    )
  end

  def endpoint
    Rails.configuration.embedding_endpoint
  end
end
