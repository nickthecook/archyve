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
      prompt = "Here is some context that may help you answer the following question:\n\n"
      @search_hits.each do |hit|
        prompt << "#{hit.content}\n\n---\n\n"
      end

      prompt << "Question: #{@message.content}\n"
    else
      @message.content
    end
  end

  private

  def link_message_with_augmentations
    @search_hits.each do |hit|
      MessageAugmentation.create!(message: @message, augmentation: hit.reference, distance: hit.distance)
    end
  end
end
