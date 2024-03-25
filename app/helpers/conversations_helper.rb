module ConversationsHelper
  def model_config_list
    ModelConfig.all
  end

  def collection_list
    current_user.collections
  end
end
