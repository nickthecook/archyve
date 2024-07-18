module V1
  module ModelsHelper
    def model_response(model)
      model.attributes.slice("id", "name", "model", "temperature")
    end
  end
end
