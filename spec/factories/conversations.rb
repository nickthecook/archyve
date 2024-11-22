FactoryBot.define do
  factory :conversation do
    model_config { association(:model_config) }
    user { association(:user) }
    messages do
      [
        build(:message, author: user, content: "Write a simple ruby program."),
        build(:message, author: model_config, content: "loop { puts 'HA' }"),
        build(:message, author: user, content: "Not exactly what I meant."),
      ]
    end
    search_collections { true }

    factory :augmented_conversation do
      messages do
        [
          build(:augmented_message, author: user),
          build(:message, author: model_config, content: "loop { puts 'HA' }"),
          build(
            :augmented_message, author: user, content: <<~CONTENT,
              Write a ruby program that lists the contents of the home directory for user 'bob'.
            CONTENT
            prompt: <<~PROMPT
              Home directories are located a /home/username or /Users/username in a sane system.
              Write a ruby program that lists the contents of the home directory for user 'bob'.
            PROMPT
          ),
        ]
      end
    end

    factory :conversation_with_collection do
      conversation_collections { [build(:conversation_collection)] }
    end

    factory :conversation_with_no_messages do
      messages { [] }
    end
  end
end
