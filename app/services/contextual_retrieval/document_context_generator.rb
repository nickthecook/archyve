module ContextualRetrieval
  class DocumentContextGenerator
    def initialize(document)
      @document = document
      @prompt_template = ERB.new(ContextualRetrieval::Prompts::PRELOAD_DOCUMENT_PROMPT)
    end

    def execute
      return unless model_helper.provider == "ollama"

      response = client.post("/api/generate", request_body, traceable: @document)

      @document.update!(context: response["context"], context_model: model_config.model)
    end

    private

    def request_body
      {
        model: model_config.model,
        prompt:,
        stream: false,
        options: {
          num_predict: 0,
        },
      }.to_json
    end

    def prompt
      @prompt_template.result(binding)
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

    def document_content
      parser.text
    end
  end
end
