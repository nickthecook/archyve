FactoryBot.define do
  factory :graph_entity_description do
    graph_entity { association(:graph_entity) }
    description { "test GraphEntityDescription" }
    chunk { association(:chunk) }
  end
end
