module SettingsHelper
  def embedding_model_list
    ModelConfig.embedding
  end

  def entity_extraction_model_list
    ModelConfig.generation
  end

  def provider_list
    options_for_select(ModelServer.providers.map { |name, _int| [name.humanize.capitalize, name] })
  end
end
