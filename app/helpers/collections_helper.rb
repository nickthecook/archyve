module CollectionsHelper
  def embedding_model_list
    ModelConfig.where(embedding: true).to_a
  end
end
