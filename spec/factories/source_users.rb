FactoryBot.define do
  factory :source_user do
    association :source
    association :user
    access { "editor" }

    trait :manager do
      access { "manager" }
    end
  end
end
