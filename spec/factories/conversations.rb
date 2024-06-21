FactoryBot.define do
  factory :conversation do
    model_config { build :model_config }
    user { build(:user) }
    messages do
      [
        build(:message, author: user, content: "Write a simple ruby program."),
        build(:message, author: model_config, content: "loop { puts 'HA' }"),
        build(:message, author: user, content: "Not exactly what I meant."),
      ]
    end
  end
end
