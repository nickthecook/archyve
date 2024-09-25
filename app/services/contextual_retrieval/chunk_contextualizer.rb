module ContextualRetrieval
  class ChunkContextualizer
    def initialize(chunk)
      @chunk = chunk
      @document = chunk.document
    end

    def execute
      @contextualization = get_client_response
      @chunk.update!(
        content: updated_chunk_content_for(@chunk.content),
        embedding_content: updated_chunk_content_for(@chunk.embedding_content),
        contextualized: true
      )
      @chunk.document.touch(:updated_at)

      EmbedChunkJob.perform_async(@chunk.id)
    end

    private

    def get_client_response
      if model_helper.provider == "ollama"
        client.post("/api/generate", request_body)["response"]
      else
        client.complete(request_body)
      end
    end

    def prompt_template
      @prompt_template ||= if model_helper.provider == "ollama"
        ERB.new(ContextualRetrieval::Prompts::CONTEXTUALIZE_CHUNK_PROMPT)
      else
        ERB.new(ContextualRetrieval::Prompts::CONTEXTUALIZE_CHUNK_PROMPT_FULLDOC)
      end
    end

    def updated_chunk_content_for(string)
      "#{@contextualization}\n\n---\n\n#{string}"
    end

    def request_body
      {
        model: model_config.model,
        prompt: prompt_for(@chunk.content),
        context: @chunk.document.context,
        stream: false,
      }.to_json
    end

    def prompt_for(input_text)
      prompt_template.result(binding)
    end

    def client
      @client ||= model_helper.client
    end

    def model_helper
      @model_helper ||= Helpers::ModelClientHelper.new(model_config:, traceable: @chunk)
    end

    def model_config
      ModelConfig.find(contextualization_model)
    end

    def contextualization_model
      Setting.get("contextualization_model")
    end

    def chunk_content
      @chunk.content
    end

    def document_content
      parser.text
    end

    def parser
      @parser ||= Parsers.parser_for(@document.filename).new(@document)
    end
  end
end
