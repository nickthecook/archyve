FactoryBot.define do
  factory :collection_membership do
    association :collection
    association :document
    origin { "manual" }

    trait :feed do
      origin { "feed" }
    end

    trait :removed do
      removed_at { Time.current }
    end
  end
end
