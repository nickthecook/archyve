module ConversationsHelper
  def model_config_list
    ModelConfig.generation
  end

  def collection_list
    current_user.collections.select(:id, :name)
  end
end
