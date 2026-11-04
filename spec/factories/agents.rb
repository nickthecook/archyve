FactoryBot.define do
  factory :agent do
    sequence(:slug) { "agent-#{it}" }
    name { "Test agent" }
    prompt { "You are a test agent." }
    toolset_keys { ["archive"] }
  end

  factory :agent_user do
    association :agent
    association :user
    access { "accessor" }
  end

  factory :agent_collection do
    association :agent
    association :collection
  end
end
