FactoryBot.define do
  factory :collection_membership do
    association :collection
    association :document
    source { "manual" }

    trait :connector do
      source { "connector" }
    end

    trait :removed do
      removed_at { Time.current }
    end
  end
end
