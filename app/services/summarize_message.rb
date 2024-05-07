class SummarizeMessage
  SUMMARY_PROMPT = "
    You are a summarization AI.
    You'll never answer a user's question directly, but instead summarize the user's request
    into a single short sentence of four words or less.
    Always start your answer with an emoji relevant to the summary.
  ".freeze

  def initialize(message)
    @message = message
    @model_config = Setting.summarization_model
    @summary = ""
  end

  def execute
    client.complete("#{SUMMARY_PROMPT}\nMessage:\n#{message_content}") do |response|
      @summary += response
    end

    @summary.lines.first.gsub(/^\d\./, "")
  end

  private

  def message_content
    @message.content
  end

  def client
    @client ||= LlmClients::Client.client_class_for(@model_config.model_server.provider).new(
      endpoint: Rails.configuration.summarization_endpoint,
      model: @model_config.model,
      api_key: "todo"
    )
  end
end
