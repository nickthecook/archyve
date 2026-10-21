FactoryBot.define do
  factory :api_key do
    association :user
    name { "Script" }
  end
end
