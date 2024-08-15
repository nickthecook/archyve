class PromptAugmentor
  def initialize(given_prompt, search_hits)
    @given_prompt = given_prompt
    @search_hits = search_hits
  end

  def prompt
    @prompt ||= begin
      prompt = "Here is some context that may help you answer the following question:\n\n"
      @search_hits.each do |hit|
        prompt << "#{hit.content}\n\n"
      end

      prompt << "Question: #{@given_prompt}\n"
    end
  end
end
