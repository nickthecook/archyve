class RespondToMessage
  def initialize(message)
    @message = message
  end

  def execute
    reply = Message.create!(
      content: "We'll be right back!",
      author: @message.conversation.model_config,
      conversation: @message.conversation
    )

    Turbo::StreamsChannel.broadcast_append_to("conversations", target: "messages", partial: "messages/message", locals: { message: reply })
  end
end
