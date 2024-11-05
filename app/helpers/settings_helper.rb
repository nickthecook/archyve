module SettingsHelper
  def settings_entity_extraction_model_list
    ModelConfig.available.generation
  end

  def settings_provider_list
    options_for_select(ModelServer.providers.map { |name, _int| [name.humanize.capitalize, name] })
  end
end
