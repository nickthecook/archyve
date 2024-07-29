FactoryBot.define do
  factory :model_server do
    name { "localhost" }
    url { "http://localhost:9999" }
    provider { "ollama" }
    active { true }
    api_key { nil }
  end
end
