FactoryBot.define do
  # Endpoint is an STI base with a NOT NULL `type`, so the default factory
  # builds a concrete subclass — the same trap the :source and :inference_server
  # factories hit.
  factory :endpoint, class: "Endpoints::Bookstack" do
    sequence(:name) { |n| "Wiki #{n}" }
    base_url { "https://wiki.example.com" }
    token_id { "tokenid" }
    token_secret { "tokensecret" }

    factory :bookstack_endpoint
  end
end
