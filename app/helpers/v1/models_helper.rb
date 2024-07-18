module V1
  module ModelsHelper
    def model_response(models)
      models.map { |model| model.attributes.slice("id", "name", "model", "temperature") }
    end
  end
end
