module Graph
  class EntitySummarizer
    def initialize(model_config, traceable: nil)
      @model_config = model_config
      @traceable = traceable
    end

    def summarize(entity)
      @entity = entity

      response = client.complete(prompt.result(binding), traceable: entity)

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
      @client ||= model_helper.client
    end

    def model_helper
      @model_helper ||= Helpers::ModelClientHelper.new(model_config: @model_config, traceable: @traceable)
    end
  end
end
