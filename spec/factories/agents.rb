FactoryBot.define do
  factory :agent do
    sequence(:slug) { "agent-#{it}" }
    name { "Test agent" }
    prompt { "You are a test agent." }
  end
end
