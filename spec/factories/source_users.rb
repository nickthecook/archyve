FactoryBot.define do
  factory :source_user do
    association :source
    association :user
    role { "curator" }

    trait :admin do
      role { "admin" }
    end
  end
end
