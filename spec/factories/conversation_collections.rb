FactoryBot.define do
  factory :conversation_collection do
    conversation { association(:conversation) }
    collection { association(:collection) }
  end
end
