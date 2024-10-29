class FetchOllamaModels
  def initialize(model_server)
    raise ArgumentError, "ModelServer is not an Ollama server" unless model_server.provider == "ollama"

    @model_server = model_server
  end

  def execute
    model_list.map do |model|
      model_details = model_details_for(model["name"], model["model"])

      ModelConfig.new(
        name: model_details.name,
        model: model_details.model,
        context_window_size: model_details.context_window_size,
        temperature: model_details.temperature,
        embedding: model_details.embedding?,
        vision: model_details.vision?
      )
    end
  end

  private

  def model_details_for(name, model)
    response = client.fetch_model_details(name)

    LlmClients::Ollama::ModelDetails.new(name, model, response)
  end

  def model_list
    @model_list ||= client.list_models["models"]
  end

  def client
    @client ||= LlmClients::Ollama::Client.new(endpoint: @model_server.url, api_key: @model_server.api_key)
  end
end
