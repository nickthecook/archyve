FactoryBot.define do
  factory :collection_membership do
    association :collection
    association :document
    source { "manual" }
  end
end
