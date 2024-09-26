class MessageAugmentor
  def initialize(message)
    @message = message
    @conversation = message.conversation
  end

  def execute
    return unless collections_to_search.any?

    search_hits = searcher.search(@message.content)

    PromptAugmentor.new(@message, search_hits).augment
  end

  private

  def collections_to_search
    @collections_to_search ||= if @conversation.search_collections
      message_collections = @conversation.collections
      message_collections.any? ? message_collections : @conversation.user.collections
    else
      []
    end
  end

  def searcher
    @searcher ||= Search::SearchN.new(
      collections_to_search,
      num_results: Setting.get(:num_chunks_to_include, default: 10),
      traceable: @conversation
    )
  end
end
