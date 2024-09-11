module OllamaProxy
  class ConversationFinder
    def initialize(chat_request, user)
      @chat_request = chat_request
      @user = user

      @message_count = @chat_request.messages_with_content.count
    end

    def find_or_create
      convo = matching_convo || create_convo

      most_recent_message = @chat_request.messages.last
      MessageCreator.new(convo, @chat_request.model).create!(
        most_recent_message.role,
        most_recent_message.content
      )

      convo
    end

    private

    def create_convo
      convo = Conversation.create!(
        user: @user,
        title: new_convo_title,
        search_collections: true,
        model_config: chat_model_config
      )

      message_creator = MessageCreator.new(convo, @chat_request.model)
      @chat_request.messages_with_content[..-2].each do |chat_message|
        message_creator.create!(chat_message.role, chat_message.content, chat_message.content)
      end

      convo
    end

    def chat_model_config
      @chat_model_config ||= ModelConfig.find_or_create_by(model: @chat_request.model) do |model_config|
        model_config.name = @chat_request.model
        model_config.available = true
      end
    end

    def matching_convo
      @matching_convo ||= convos_with_correct_message_count.find do |convo|
        all_messages_match?(convo)
      end
    end

    def all_messages_match?(convo)
      match = true

      convo.messages.each_with_index do |message, index|
        match = MessageMatcher.new(message, @chat_request.messages_with_content[index]).match?

        break if match == false
      end

      match
    end

    def convos_with_correct_message_count
      recent_convos.joins(:messages).group("conversations.id").having("count(conversation_id) = ?", @message_count - 1)
    end

    def recent_convos
      @user.conversations.order(updated_at: :desc).limit(num_recent_convos)
    end

    def new_convo_title
      "(OPP) #{@chat_request.messages.first.content}".truncate(num_title_chars)
    end

    def num_recent_convos
      Setting.get(:opp_num_recent_convos_for_match, default: 10)
    end

    def num_title_chars
      Setting.get(:opp_num_conversation_title_chars, default: 80)
    end
  end
end
