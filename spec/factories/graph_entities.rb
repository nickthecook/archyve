FactoryBot.define do
  factory :graph_entity do
    entity_type { 'test object' }
    name { "Test GraphEntity" }
    collection { association(:collection) }
  end
end
