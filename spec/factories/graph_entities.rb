FactoryBot.define do
  factory :graph_entity do
    entity_type { 'test object' }
    name { "Test GraphEntity" }
    collection { association(:collection) }
  end
  factory :graph_entity_summarized, class: "GraphEntity" do
    entity_type { 'test object' }
    name { "Test GraphEntity" }
    summary { Faker::Lorem.sentence(word_count: 5) }
    collection { association(:collection) }
  end
end
