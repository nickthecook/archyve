class PromptAugmentor
  def initialize(message, search_hits)
    @message = message
    @search_hits = search_hits
  end

  def augment
    @message.update!(prompt:)

    link_message_with_augmentations
  end

  def prompt
    @prompt ||= if @search_hits.any?
      # prompt = "You are given a query to answer based on some given textual context, all inside xml tags.\nIf the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.\n\n" # rubocop:disable Layout/LineLength
      prompt = <<~CONTENT
        You are given a query to answer based on some given textual context, all inside xml tags.
        If the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.

      CONTENT
      @search_hits.each do |hit|
        prompt << prompt_context(hit)
      end
      prompt << "<user_query>\n#{@message.content}\n<user_query>\n"
    else
      @message.content
    end
  end

  private

  def prompt_context(hit)
    if hit.document.web?
      "<context>\n<url>#{hit.document.link}</url>\n<scraped>#{hit.document.created_at}</scraped>\n<text>#{hit.content}</text>\n</context>\n" # rubocop:disable Layout/LineLength
    else
      "<context>\n<filename>#{hit.document.filename}</filename>\n<text>#{hit.content}</text>\n</context>\n"
    end
  end

  def link_message_with_augmentations
    @search_hits.each do |hit|
      MessageAugmentation.create!(message: @message, augmentation: hit.reference, distance: hit.distance)
    end
  end
end
