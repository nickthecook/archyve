FactoryBot.define do
  factory :setting do
    sequence(:key) { |n| "key_#{n}" }
    sequence(:value) { |n| "value_#{n}" }
    target { nil }
  end
end
