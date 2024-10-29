class FetchOllamaModels
  def initialize(model_server)
    @model_server = model_server
  end

  def execute
    model_list.map do |model|
      model_info = model_info_for(model["name"], model["model"])

      ModelConfig.new(
        name: model_info.name,
        model: model_info.model,
        context_window_size: model_info.context_window_size,
        temperature: model_info.temperature
      )
    end
  end

  private

  def model_info_for(name, model)
    response = client.fetch_model_info(name)

    ModelInfo.new(name, model, response)
  end

  def model_list
    @model_list ||= client.list_models["models"]
  end

  def client
    @client ||= LlmClients::Ollama::Client.new(endpoint: @model_server.url, api_key: @model_server.api_key)
  end
end
