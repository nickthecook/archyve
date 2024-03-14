module MessagesHelper
  def author_name_for(message)
    if message.author.is_a?(User)
      message.author.email
    else
      message.author.name
    end
  end
end
