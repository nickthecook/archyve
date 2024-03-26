require "net/http"

class ReplyToMessage
  STATS = [:elapsed_ms, :tokens, :tokens_per_sec].freeze

  def initialize(message)
    @message = message
  end

  def execute
    search if collections_to_search.any?

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
    Rails.logger.error("\nNetworkError: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: "A network error occurred: #{e.message}" })
  rescue LlmClients::ResponseError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: "#{e.to_s}: #{e.additional_info}" })
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: "An internal error occurred" })
  ensure
    remove(reply_id, "messages/spinner") if @reply
  end

  private

  def broadcast_event(event_content, dom_id)
    return unless collections_to_search.any?

    Turbo::StreamsChannel.broadcast_append_to(
      "conversations",
      target: "messages",
      partial: "shared/conversation_event",
      locals: {
        event_content:,
        text_class: "text-xs",
        dom_id:
      }
    )
  end

  def collections_to_search
    @collections_to_search ||= @message.conversation.collections
  end

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
        model: model_config.model,
        provider: model_config.model_server.provider
      },
      prompt
    )
  end

  def search_results
    @search_results ||= searcher.search(@message.content)
  end

  def prompt
    @prompt ||= begin
      return @message.content unless collections_to_search.any?

      prompt = "Given this context, answer the following question:\n\n"
      search_results.each do |chunk|
        prompt << "#{chunk.content}\n\n"
      end

      prompt << "Question: #{@message.content}"
    end
  end

  def search
    broadcast_event(
      "Searching #{collections_to_search.map(&:name).join(', ')}...",
      "message_#{@message.id}-collections-event"
    )
    broadcast_event(
      "#{search_results.count} hits.",
      "message_#{@message.id}-count-event"
    )
    broadcast_event(
      "Sending prompt: #{prompt}",
      "message_#{@message.id}-prompt-event"
    )
  end

  def searcher
    # TODO: support more than one collection
    @searcher ||= Search.new(collections_to_search.first)
  end

  def model_config
    @message.conversation.model_config
  end

  def reply_id
    @reply_id ||= "message_#{@reply.id}"
  end
end
