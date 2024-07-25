module Api
  class ModelLoader
    def initialize(model:, traceable:)
      @model = model
      @traceable = traceable

      check_model
      check_model_server
    end

    def model_config
      @model_config ||= if @model.present?
        ModelConfig.find_by(name: @model) || ModelConfig.find_by(model: @model)
      else
        Setting.chat_model
      end
    end

    def client(provider)
      @client ||= LlmClients::Client.client_class_for(provider).new(
        endpoint: model_server.url,
        api_key: model_server.api_key,
        model: model_config.model,
        traceable: @traceable
      )
    end

    private

    def model_server
      model_config.model_server || ModelServer.active_server
    end

    def check_model
      return if model_config

      if @model.nil?
        raise ModelError, "No model given, and no default chat model configured."
      elsif @model
        raise ModelNotFoundError, "Given model '#{@model}' not found."
      end
    end

    def check_model_server
      return if model_server

      raise ModelError, "No ModelServer configured. Please create one through the admin UI."
    end
  end
end
