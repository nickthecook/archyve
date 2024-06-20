require "net/http"

# TODO: fix this; disabled rubocop for now because I can't read the code with all the squigglies
# rubocop:disable Metrics/ClassLength, Metrics/AbcSize
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

    append("messages", "messages/error", { error: e })
  rescue Errno::ECONNREFUSED => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: e })
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    append("messages", "messages/error", { error: "An internal error occurred" })
  end

  private

  def broadcast_event(event_content, dom_id, pre: false, summary: nil)
    return unless collections_to_search.any?

    Turbo::StreamsChannel.broadcast_append_to(
      channel_name,
      target: "messages",
      partial: "shared/conversation_event",
      locals: {
        event_content:,
        text_class: "text-xs",
        dom_id:,
        pre:,
        summary:,
      }
    )
  end

  def collections_to_search
    @collections_to_search ||= if @message.conversation.search_collections
      message_collections = @message.conversation.collections
      message_collections.any? ? message_collections : @message.conversation.user.collections
    else
      []
    end
  end

  def convert_to_markdown
    Turbo::StreamsChannel.broadcast_append_to(
      channel_name,
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
    Turbo::StreamsChannel.broadcast_append_to(channel_name, target:, partial:, locals:)
  end

  def prepend(target, partial, locals = {})
    locals.merge!({ message: @reply })
    Turbo::StreamsChannel.broadcast_prepend_to(channel_name, target:, partial:, locals:)
  end

  def replace(target, partial, locals = {})
    locals.merge!({ message: @reply })
    Turbo::StreamsChannel.broadcast_replace_to(target, partial:)
  end

  def remove(target)
    Turbo::StreamsChannel.broadcast_remove_to(target)
  end

  def streamer
    @streamer ||= ResponseStreamer.new(
      {
        endpoint: ModelServer.active_server.url,
        model: model_config.model,
        provider: ModelServer.active_server.provider,
      },
      prompt
    )
  end

  def search_hits
    @search_hits ||= searcher.search(@message.content)
  end

  def prompt
    @prompt ||= begin
      return @message.content unless collections_to_search.any?

      prompt = "Here is some context that may help you answer the following question:\n\n"
      search_hits.each do |hit|
        prompt << "#{hit.chunk.content}\n\n"
      end

      prompt << "Question: #{@message.content}"
    end
  end

  def search
    broadcast_event(
      "Searching the Archyve...",
      "message_#{@message.id}-collections-event"
    )
    broadcast_event(
      prompt,
      "message_#{@message.id}-prompt-event",
      pre: true,
      summary: "#{search_hits.count} hits added to context"
    )
  end

  def searcher
    @searcher ||= Search::SearchMultiple.new(collections_to_search, num_results: 10)
  end

  def model_config
    @message.conversation.model_config
  end

  def reply_id
    @reply_id ||= "message_#{@reply.id}"
  end

  def channel_name
    "#{@message.conversation.user.id}_conversations"
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize
