class SetConversationTitle
  def initialize(conversation)
    @conversation = conversation
  end

  def execute
    @conversation.update!(title: summarizer.execute)
  end

  private

  def summarizer
    SummarizeMessage.new(@conversation.messages.first)
  end
end
