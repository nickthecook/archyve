FactoryBot.define do
  factory :model_server do
    name { "localhost" }
    url { "http://localhost:9999" }
    provider { "ollama" }
    active { true }
  end
end
