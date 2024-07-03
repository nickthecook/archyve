class SummarizeMessage
  SUMMARY_PROMPT = "
    You are a summarization AI.
    You'll never answer a user's question directly, but instead summarize the user's request
    into a single short sentence of four words or less.
    Always start your answer with an emoji relevant to the summary.
  ".freeze

  def initialize(message, traceable: nil)
    @message = message
    @traceable = traceable
    @model_config = Setting.summarization_model
    @summary = ""
  end

  def execute
    client.complete("#{SUMMARY_PROMPT}\nMessage:\n#{message_content}") do |response|
      @summary += response
    end

    Rails.logger.info("Got summary: #{@summary}")
    @summary.lines.find(&:present?)&.gsub(/^\d\./, "")
  end

  private

  def message_content
    @message.content
  end

  def client
    @client ||= LlmClients::Client.client_class_for(active_server.provider).new(
      endpoint: active_server.url,
      model: @model_config.model,
      api_key: "todo",
      traceable: @traceable
    )
  end

  def active_server
    @active_server ||= ModelServer.active_server
  end
end
