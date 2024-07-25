module Helpers
  class ModelClientHelper
    BATCH_SIZE = 16

    def initialize(model_config:, traceable: nil)
      @model_config = model_config
      @server = @model_config.model_server || ModelServer.active_server
      @traceable = traceable
    end

    def endpoint
      @server.url
    end

    def server_name
      @server.name
    end

    def provider
      @server.provider
    end

    def model
      @model_config.model
    end

    def embedding_model?
      @model_config.embedding?
    end

    def client
      return @client if @client

      # either embedding or regular model, never both
      emb_model = embedding_model? && model
      reg_model = emb_model ? nil : model
      @client = LlmClients::Client.client_class_for(provider).new(
        endpoint:,
        api_key: @server.api_key,
        model: reg_model,
        embedding_model: emb_model,
        api_version: @model_config.api_version,
        batch_size: BATCH_SIZE,
        traceable: @traceable
      )
    end
  end
end
