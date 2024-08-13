module Graph
  class EntitySummarizer
    def initialize(model_config, traceable: nil)
      @model_config = model_config
      @traceable = traceable
    end

    def summarize(entity)
      @entity = entity

      response = client.complete(prompt.result(binding))

      @entity.update!(summary: response, summary_outdated: false)
    end

    private

    def prompt
      @prompt ||= ERB.new(Graph::Prompts::ENTITY_SUMMARIZATION_PROMPT)
    end

    def entity_name
      @entity.name
    end

    def description_list
      @entity.descriptions.map(&:description).join("\n")
    end

    def client
      @client ||= LlmClients::Client.client_class_for(ModelServer.active_server.provider).new(
        endpoint: ModelServer.active_server.url,
        model: @model_config.model,
        api_key: "todo",
        traceable: @traceable
      )
    end
  end
end
