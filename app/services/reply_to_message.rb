require "net/http"

# TODO: fix this; disabled rubocop for now because I can't read the code with all the squigglies
# rubocop:disable Metrics/AbcSize
class ReplyToMessage
  STATS = [:elapsed_ms, :tokens, :tokens_per_sec].freeze

  def initialize(message)
    @message = message
    @conversation = @message.conversation
  end

  def execute
    augment_message_prompt
    chat.chat_history
    create_reply

    streamer.chat(chat) do |message, raw_message|
      Rails.logger.info("Got back: #{message}")
      Rails.logger.info("And raw:  #{raw_message}")
      @reply.update!(content: @reply.content + message, raw_content: @reply.raw_content + raw_message)

      convert_to_markdown
    end

    @reply.update!(statistics:)
  rescue LlmClients::ResponseError, Errno::ECONNREFUSED, EOFError, ResponseStreamer::ResponseStreamerError,
         ResponseStreamer::NetworkError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    active_message.update!(error: { message: e })
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    active_message.update!(error: { message: "An internal error occurred: #{e}" })
  end

  private

  def augment_message_prompt
    return unless collections_to_search.any?

    @message.update!(prompt: prompt_augmentor.prompt)
  end

  def create_reply
    @reply = Message.create!(
      content: "",
      raw_content: "",
      author: @conversation.model_config,
      conversation: @conversation
    )

    prepend(reply_id, "messages/spinner")
  end

  def active_message
    @reply || @message
  end

  def collections_to_search
    @collections_to_search ||= if @conversation.search_collections
      message_collections = @conversation.collections
      message_collections.any? ? message_collections : @conversation.user.collections
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

  def prepend(target, partial, locals = {})
    locals.merge!({ message: @reply })
    Turbo::StreamsChannel.broadcast_prepend_to(channel_name, target:, partial:, locals:)
  end

  def streamer
    # TODO: add api_key to ModelServer
    @streamer ||= ResponseStreamer.new(
      endpoint: ModelServer.active_server.url,
      model: model_config.model,
      provider: ModelServer.active_server.provider,
      traceable: @conversation
    )
  end

  def searcher
    @searcher ||= Search::SearchN.new(
      collections_to_search,
      num_results: Setting.get(:num_chunks_to_include),
      traceable: @conversation
    )
  end

  def model_config
    @conversation.model_config
  end

  def reply_id
    @reply_id ||= "message_#{@reply.id}"
  end

  def channel_name
    "#{@conversation.user.id}_conversations"
  end

  def statistics
    streamer.stats.merge({ server: ModelServer.active_server.name })
  end

  def chat
    @chat ||= LlmClients::Ollama::Chat.new(@message)
  end

  def prompt_augmentor
    @prompt_augmentor ||= begin
      search_hits = searcher.search(@message.content)

      PromptAugmentor.new(@message.content, search_hits)
    end
  end
end
# rubocop:enable Metrics/AbcSize
