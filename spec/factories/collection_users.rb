FactoryBot.define do
  factory :collection_user do
    association :collection
    association :user
    role { "user" }

    trait :operator do
      role { "operator" }
    end

    trait :admin do
      role { "admin" }
    end
  end
end
