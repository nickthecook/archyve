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
    if @search_hits.none?(&:relevant)
      return "The query found hits, but none were relevant. Query: #{@message.content}\n"
    end

    @prompt ||= if @search_hits.any?
      prompt = <<~CONTENT
        You are given a query to answer based on some given textual context, all inside xml tags.
        If the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.

        <context>
      CONTENT

      @search_hits.each do |hit|
        prompt << "<context_item name=\"#{hit.name}\">\n"
        prompt << context_item(hit)
        prompt << "</context_item>\n"
      end

      prompt << "</context>\n\n"
      prompt << "Query: #{@message.content}\n"
    else
      @message.content
    end
  end

  private

  def context_item(hit)
    if hit.document.nil?
      "<text>#{hit.content}</text>\n"
    elsif hit.document.web?
      "<url>#{hit.document.link}</url>\n<scraped>#{hit.document.created_at}</scraped>\n<text>#{hit.content}</text>\n"
    else
      "<filename>#{hit.document.filename}</filename>\n<text>#{hit.content}</text>\n"
    end
  end

  def link_message_with_augmentations
    @search_hits.each do |hit|
      MessageAugmentation.create!(message: @message, augmentation: hit.reference, distance: hit.distance)
    end
  end
end
