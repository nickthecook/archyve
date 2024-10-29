module SettingsHelper
  def embedding_model_list
    ModelConfig.embedding
  end

  def entity_extraction_model_list
    ModelConfig.generation
  end

  def provider_list
    options_for_select([%w[Ollama ollama], %w[OpenAI openai]])
  end
end
