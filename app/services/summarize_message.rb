class SummarizeMessage
  SUMMARY_PROMPT = "
    You are a summarization AI.
    You'll never answer a user's question directly, but instead summarize the user's request
    into a single short sentence of four words or less.
    Always start your answer with an emoji relevant to the summary.
  ".freeze
  FALLBACK_SUMMARY_LENGTH = 80

  def initialize(message, traceable: nil)
    @client_helper = Helpers::ModelClientHelper.new(model_config: Setting.summarization_model, traceable:)
    @message = message
    @summary = ""
  end

  def execute
    client.complete("#{SUMMARY_PROMPT}\nMessage:\n#{message_content}") do |response|
      @summary += response
    end

    @summary.lines.find(&:present?)&.gsub(/^\d\./, "")
  rescue StandardError => e
    Rails.logger.error("#{e.class.name}: #{e.message}\n#{e.backtrace.join("\n")}")

    @summary = @message.content.truncate(FALLBACK_SUMMARY_LENGTH)
  end

  private

  def client
    @client_helper.client
  end

  def message_content
    @message.content
  end
end
