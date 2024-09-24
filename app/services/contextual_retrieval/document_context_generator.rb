module ContextualRetrieval
  class DocumentContextGenerator
    def initialize(document)
      @document = document
    end

    def execute
      response = client.post("/api/generate", request_body, traceable: @document)

      @document.update!(context: response["context"], context_model: model_config.model)
    end

    private

    def request_body
      {
        model: model_config.model,
        prompt: parser.text,
        stream: false,
        options: {
          num_predict: 0,
        },
      }.to_json
    end

    def parser
      @parser ||= Parsers.parser_for(@document.filename).new(@document)
    end

    def client
      @client ||= model_helper.client
    end

    def model_helper
      @model_helper ||= Helpers::ModelClientHelper.new(model_config:)
    end

    def model_config
      ModelConfig.find(contextualization_model)
    end

    def contextualization_model
      Setting.get("contextualization_model")
    end
  end
end
