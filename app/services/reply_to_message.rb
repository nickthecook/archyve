class ReplyToMessage
  STATS = [:elapsed_ms, :tokens, :tokens_per_sec].freeze

  def initialize(message)
    @message = message
  end

  def execute
    reply = Message.create!(
      content: "We'll be right back! (#{@message.id})",
      author: @message.conversation.model_config,
      conversation: @message.conversation
    )

    append("messages", "messages/message", { message: reply })
  end

  private

  def append(target, partial, locals)
    Turbo::StreamsChannel.broadcast_append_to("conversations", target:, partial:, locals:)
  end

  def replace(target, partial, locals)
    Turbo::StreamsChannel.broadcast_replace_to(target, partial:)
  end

  def remove(target)
    Turbo::StreamsChannel.broadcast_remove_to(target)
  end

  def streamer
    @streamer ||= ResponseStreamer.new(@message.model_config, @message.content)
  end

  def reply_id
    @reply_id ||= "message_#{@message.id}"
  end
end
