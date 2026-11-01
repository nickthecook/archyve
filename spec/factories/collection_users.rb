FactoryBot.define do
  factory :collection_user do
    association :collection
    association :user
    access { "accessor" }

    trait :editor do
      access { "editor" }
    end

    trait :manager do
      access { "manager" }
    end
  end
end
