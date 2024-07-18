module V1
  class ModelsController < ApiController
    def index
      render json: { models: helpers.model_response(model_configs) }
    end

    private

    def model_configs(embedding = nil)
      return ModelConfig.embedding if embedding&.true?
      return ModelConfig.generation if embedding&.false?

      ModelConfig.all
    end
  end
end
