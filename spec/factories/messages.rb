FactoryBot.define do
  factory :message do
    author { build(:user) }
    content { "Write a simple ruby program." }
  end
end
