module CollectionsHelper
  def embedding_model_list
    ModelConfig.where(embedding: true).to_a
  end

  def state_text_for(collection)
    case collection.state
    when "errored" then "Error"
    else collection.state.capitalize
    end
  end
end
