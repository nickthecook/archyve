module Ollama
  class SyncModels
    def initialize(model_server)
      raise ArgumentError, "ModelServer is not an Ollama server" unless model_server.provider == "ollama"

      @model_server = model_server
    end

    def execute
      model_set
      @model_server.transaction do
        update_existing
        add_new
        remove_old
      end
    end

    private

    def add_new
      model_set.each do |model_details|
        existing = find_existing_model(model_details)
        next if existing

        ModelConfig.create!(
          name: model_details.name,
          model: model_details.model,
          context_window_size: model_details.context_window_size,
          temperature: model_details.temperature,
          embedding: model_details.embedding?,
          vision: model_details.vision?,
          available: true,
          model_server: @model_server
        )
      end
    end

    def update_existing
      model_set.each do |model_details|
        existing = find_existing_model(model_details)
        next unless existing

        existing.update!(
          name: model_details.name,
          model: model_details.model,
          context_window_size: model_details.context_window_size,
          temperature: model_details.temperature,
          embedding: model_details.embedding?,
          vision: model_details.vision?,
          available: true
        )
      end
    end

    def remove_old
      @model_server.model_configs.each do |model_config|
        model_config.mark_as_unavailable if model_set.none? do |model_details|
          model_config.name == model_details.name && model_config.model == model_details.model
        end
      end
    end

    def find_existing_model(model_details)
      ModelConfig.available.where(model_server: nil)
        .or(ModelConfig.available.where(model_server: @model_server))
        .find_by(name: model_details.name, model: model_details.model)
    end

    def model_set
      @model_set ||= FetchModels.new(@model_server).execute
    end
  end
end
