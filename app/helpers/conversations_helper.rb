module ConversationsHelper
  def model_config_list
    ModelConfig.generation.available
  end

  def collection_list(user)
    user.collections.select(:id, :name)
  end
end
