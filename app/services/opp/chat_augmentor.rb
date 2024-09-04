module Opp
  class ChatAugmentor
    def initialize(chat_request, user)
      @chat_request = chat_request
      @user = user
    end

    def execute
      return if message_to_augment.nil?

      MessageAugmentor.new(message_to_augment).execute

      message_to_augment
    end

    private

    def message_to_augment
      @message_to_augment ||= conversation.messages.last
    end

    def conversation
      @conversation ||= ConversationFinder.new(@chat_request, @user).find_or_create
    end
  end
end
