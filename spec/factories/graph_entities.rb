FactoryBot.define do
  factory :graph_entity do
    entity_type { 'test object' }
    name { "Test GraphEntity" }
    summary { Faker::Lorem.sentence(word_count: 5) }
    collection { association(:collection) }
  end
end
