class SummarizeMessage
  SUMMARY_PROMPT = "Provide a five word summary for the following message. Only provide the five word summary, no additional details."

  def initialize(message, model_config = nil)
    @message = message
    @model_config = model_config || @message.conversation.model_config
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
      model: Rails.configuration.summarization_model,
      api_key: "todo"
    )
  end
end
