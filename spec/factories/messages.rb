FactoryBot.define do
  factory :message do
    author { association(:user) }
    content { "Write a simple ruby program." }

    factory :augmented_message do
      prompt { "Ruby is an expressive language. Ruby has strong metaprogramming capabilities." }
    end
  end
end
