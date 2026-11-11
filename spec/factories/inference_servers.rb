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

  factory :azure_server, class: "InferenceServers::Azure" do
    sequence(:name) { |n| "Azure #{n}" }
    base_url { "https://archyve-test.openai.azure.com" }
    api_key { "azure-test" }
  end
end
