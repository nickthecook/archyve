class Embedder
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def embed(document)
    response = client.embed(document)

    response["embedding"]
  end

  private

  def client
    @client ||= LlmClients::Ollama.new(
      endpoint: @endpoint,
      api_key: "todo"
    )
  end
end
