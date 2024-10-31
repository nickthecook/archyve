module ConversationsHelper
  def model_config_list
    ModelConfig.available.generation
  end

  def collection_list(user)
    user.collections.select(:id, :name)
  end
end
