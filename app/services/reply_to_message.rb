require "net/http"

class ReplyToMessage
  STATS = [:elapsed_ms, :tokens, :tokens_per_sec].freeze

  def initialize(message)
    @message = message
  end

  def execute
    @reply = Message.create!(
      content: "",
      author: @message.conversation.model_config,
      conversation: @message.conversation
    )

    append(reply_id, "messages/spinner", { message: @reply })

    streamer.stream do |message|
      Rails.logger.info("Got back: #{message}")
      @reply.update!(content: @reply.content + message)

      convert_to_markdown
    end
  end

  private

  def convert_to_markdown
    Turbo::StreamsChannel.broadcast_append_to(
      "conversations",
      target: reply_id,
      html: "<script>document.getElementById('#{reply_id}').dataset.markdownTextUpdatedValue = #{Time.current.to_f};</script>"
    )
  end

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
    @streamer ||= ResponseStreamer.new(
      {
        endpoint: model_config.model_server.url,
        model: model_config.name,
        provider: model_config.model_server.provider
      },
      @message.content
    )
  end

  def model_config
    @message.conversation.model_config
  end

  def reply_id
    @reply_id ||= "message_#{@reply.id}"
  end
end
