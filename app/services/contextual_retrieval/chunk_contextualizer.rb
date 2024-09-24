module ContextualRetrieval
  class ChunkContextualizer
    def initialize(chunk)
      @chunk = chunk
      @prompt_template = ERB.new(ContextualRetrieval::Prompts::CONTEXTUALIZE_CHUNK_PROMPT)
    end

    def execute
      response = client.post("/api/generate", request_body)

      @contextualization = response["response"]
      @chunk.update!(
        content: updated_chunk_content_for(@chunk.content),
        embedding_content: updated_chunk_content_for(@chunk.embedding_content)
      )

      EmbedChunkJob.perform_async(@chunk.id)
    end

    private

    def updated_chunk_content_for(string)
      "#{@contextualization}\n\n#{string}"
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
      @prompt_template.result(binding)
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
  end
end
