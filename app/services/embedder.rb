class Embedder
  def initialize(model_config)
    @model_config = model_config
  end

  def embed(document)
    response = client.embed(document)
    puts response
  end

  private

  def client
    @client ||= LlmClients::Ollama.new(
      endpoint: @model_config.model_server.url,
      model: @model_config.model,
      api_key: "todo"
    )
  end
end
