module Graph
  # TODO: use this or remove it - skipping it in the flow for now
  # The results aren't good, and don't make sense for many types of document.
  # E.g. the start date and end date don't make sense for books, essays, RFPs, etc.
  # Without the dates, Claims are basically Relationships.
  class ClaimExtractor
    def initialize(model_config, chunk)
      @model_config = model_config
      @chunk = chunk
      @prompt = ERB.new(Graph::CLAIM_EXTRACTION_PROMPT).result(binding)
    end

    def extract
      client.complete(@prompt)
    end

    private

    def client
      @client ||= LlmClients::Client.client_class_for(active_server.provider).new(
        endpoint: active_server.url,
        model: @model_config.model,
        api_key: "todo",
        traceable: @traceable
      )
    end

    def active_server
      @active_server ||= ModelServer.active_server
    end

    ###
    # template values
    def tuple_delimiter
      "|"
    end

    def record_delimiter
      "##"
    end

    def completion_delimiter
      "|COMPLETE|"
    end

    def entity_specs
      @chunk.entities.map(&:name)
    end

    def claim_description
      "Any claims or facts that could be relevant to information discovery."
    end

    def input_text
      @chunk.content
    end
  end
end
