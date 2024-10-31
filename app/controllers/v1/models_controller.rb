module V1
  class ModelsController < ApiController
    def index
      render json: { models: model_configs.map { |model| helpers.model_response(model) } }
    rescue StandardError => e
      render json: { error: e }, status: :internal_server_error
    end

    def show
      render json: { model: helpers.model_response(model_config) }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "No model with name, model string, or id '#{id_param}'." }, status: :not_found
    rescue StandardError => e
      render json: { error: e }, status: :internal_server_error
    end

    private

    def id_param
      @id_param ||= CGI.unescape(params[:id])
    end

    def model_config
      ModelConfig.available.find_by(name: id_param) ||
        ModelConfig.available.find_by(model: id_param) ||
        ModelConfig.find(id_param)
    end

    def model_configs(embedding = nil)
      return ModelConfig.available.embedding if embedding&.true?
      return ModelConfig.available.generation if embedding&.false?

      ModelConfig.available
    end
  end
end
