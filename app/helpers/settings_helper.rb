module SettingsHelper
  def embedding_model_list
    ModelConfig.embedding
  end

  def entity_extraction_model_list
    ModelConfig.generation
  end
end
