FactoryBot.define do
  # InferenceServer is an STI base with a NOT NULL `type`, so the default
  # factory builds a concrete subclass — the same trap the :source factory hit.
  factory :inference_server, class: "InferenceServers::Ollama" do
    sequence(:name) { |n| "Ollama #{n}" }
    base_url { "http://localhost:11434" }

    factory :ollama_server
  end

  factory :openai_server, class: "InferenceServers::OpenAI" do
    sequence(:name) { |n| "OpenAI #{n}" }
    api_key { "sk-test" }
  end
end
