FactoryBot.define do
  factory :collection_user do
    association :collection
    association :user
    role { "user" }

    trait :curator do
      role { "curator" }
    end

    trait :admin do
      role { "admin" }
    end
  end
end
