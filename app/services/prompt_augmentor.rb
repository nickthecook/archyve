class PromptAugmentor
  def initialize(message, search_hits)
    @message = message
    @search_hits = search_hits
  end

  def prompt
    @prompt ||= begin
      prompt = "Here is some context that may help you answer the following question:\n\n"
      @search_hits.sort_by { |hit| hit.chunk.id }.each do |hit|
        prompt << "#{hit.chunk.content}\n\n"
      end

      prompt << "Question: #{@message.content}\n"
    end
  end
end
