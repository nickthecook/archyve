module CollectionsHelper
  def embedding_model_list
    ModelConfig.where(embedding: true).to_a
  end

  def state_label_for(collection)
    state_text = state_text_for(collection)
    return state_text unless state_text.end_with?("ing")

    if collection.process_step.present? && collection.process_steps.present?
      "#{state_text} (#{collection.process_step}/#{collection.process_steps})"
    else
      state_text
    end
  end

  def state_text_for(collection)
    case collection.state
    when "errored" then "Error"
    else collection.state.capitalize
    end
  end
end
