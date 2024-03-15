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

    prepend(reply_id, "messages/spinner")

    streamer.stream do |message|
      Rails.logger.info("Got back: #{message}")
      @reply.update!(content: @reply.content + message)

      convert_to_markdown
    end

    append("messages", "messages/stats", { stats: streamer.stats })
  rescue ResponseStreamer::ResponseStreamerError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: e.to_s })
  rescue ResponseStreamer::NetworkError
    raise
  rescue LlmClients::ResponseError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: "#{e.to_s}: #{e.additional_info}" })
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: "An internal error occurred" })
  ensure
    remove(reply_id, "messages/spinner")
  end

  private

  def convert_to_markdown
    Turbo::StreamsChannel.broadcast_append_to(
      "conversations",
      target: reply_id,
      html: <<~HTML
        <script>
          document.getElementById('#{reply_id}').dataset.markdownTextUpdatedValue = #{Time.current.to_f};
        </script>
      HTML
    )
  end

  def append(target, partial, locals = {})
    locals.merge!({ message: @reply })
    Turbo::StreamsChannel.broadcast_append_to("conversations", target:, partial:, locals:)
  end

  def prepend(target, partial, locals = {})
    locals.merge!({ message: @reply })
    Turbo::StreamsChannel.broadcast_prepend_to("conversations", target:, partial:, locals:)
  end

  def replace(target, partial, locals = {})
    locals.merge!({ message: @reply })
    Turbo::StreamsChannel.broadcast_replace_to(target, partial:)
  end

  def remove(target, partial, locals = {})
    locals.merge!({ message: @reply })
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
