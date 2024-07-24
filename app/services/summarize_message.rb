class SummarizeMessage
  include Helpers::ModelClient

  SUMMARY_PROMPT = "
    You are a summarization AI.
    You'll never answer a user's question directly, but instead summarize the user's request
    into a single short sentence of four words or less.
    Always start your answer with an emoji relevant to the summary.
  ".freeze

  def initialize(message, traceable: nil)
    super(model_config: Setting.summarization_model, traceable:)
    @message = message
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
end
