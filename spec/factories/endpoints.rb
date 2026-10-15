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

  factory :nextcloud_endpoint, class: "Endpoints::Nextcloud" do
    sequence(:name) { |n| "Cloud #{n}" }
    base_url { "https://cloud.test" }
    username { "archyve" }
    app_password { "apppassword" }
  end

  # The origin only — a path here is a validation error, since the path prefix
  # belongs to the source.
  factory :web_endpoint, class: "Endpoints::Web" do
    sequence(:name) { |n| "Site #{n}" }
    base_url { "https://docs.test" }
  end
end
