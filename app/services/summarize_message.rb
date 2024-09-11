class SummarizeMessage
  def initialize(message, traceable: nil)
    @client_helper = Helpers::ModelClientHelper.new(model_config: Setting.summarization_model, traceable:)
    @message = message
    @summary = ""
  end

  def execute
    client.chat_raw(summary_chat) do |response|
      @summary += response
    end

    @summary.lines.find(&:present?)&.gsub(/^\d\./, "")
  rescue StandardError => e
    Rails.logger.error("#{e.class.name}: #{e.message}\n#{e.backtrace.join("\n")}")

    @summary = @message.content
  end

  private

  def summary_chat
    [
      {
        role: "system",
        content: <<~CONTENT,
          You are a summarization AI. You'll never answer a user's question directly, but instead summarize
          the user's request into a single short sentence of four words or less. Always start your answer
          with an emoji relevant to the summary",
        CONTENT
      },
      { role: "user", content: "Who is the president of Gabon?" },
      { role: "assistant", content: "🇬🇦 President of Gabon" },
      { role: "user", content: "Who is Julien Chaumond?" },
      { role: "assistant", content: "🧑 Julien Chaumond" },
      { role: "user", content: "what is 1 + 1?" },
      { role: "assistant", content: "🔢 Simple math operation" },
      { role: "user", content: "What are the latest news?" },
      { role: "assistant", content: "📰 Latest news" },
      { role: "user", content: "How to make a great cheesecake?" },
      { role: "assistant", content: "🍰 Cheesecake recipe" },
      { role: "user", content: "what is your favorite movie? do a short answer." },
      { role: "assistant", content: "🎥 Favorite movie" },
      { role: "user", content: "Explain the concept of artificial intelligence in one sentence" },
      { role: "assistant", content: "🤖 AI definition" },
      { role: "user", content: "Draw a cute cat" },
      { role: "assistant", content: "🐱 Cute cat drawing" },
      { role: "user", content: @message.content },
    ]
  end

  def client
    @client_helper.client
  end
end
