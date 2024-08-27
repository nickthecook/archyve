module MessagesHelper
  def author_name_for(message)
    if message.author.is_a?(User)
      message.author.email
    else
      message.author.name
    end
  end

  def partial_for_augmentation(augmentation)
    case augmentation.augmentation_type
    when "Chunk"
      "messages/chunk"
    when "GraphEntity"
      "messages/entity"
    end
  end
end
