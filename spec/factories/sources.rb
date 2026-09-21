FactoryBot.define do
  # Source is an STI base with a NOT NULL `type`, so the default factory
  # builds a concrete subclass. ManualUpload is the only one so far; add named
  # factories for other source types as they arrive.
  factory :source, class: "Sources::ManualUpload" do
    sequence(:name) { |n| "Source #{n}" }

    factory :manual_upload_source do
      name { "Manual Upload" }
    end
  end

  # Needs an Endpoints::Bookstack: the source validates the pairing.
  factory :bookstack_source, class: "Sources::Bookstack" do
    sequence(:name) { |n| "Wiki #{n}" }
    endpoint factory: :bookstack_endpoint
    selectors { [{ "book" => 1 }] }
  end

  # Needs an Endpoints::Web: the source validates the pairing.
  factory :web_source, class: "Sources::Web" do
    sequence(:name) { |n| "Docs #{n}" }
    endpoint factory: :web_endpoint
    path_prefix { "/docs" }
  end

  # Points at a real temporary directory, since the source validates that its
  # path exists and is readable. Pass `path` to point it at a fixture tree.
  factory :folder_source, class: "Sources::Folder" do
    sequence(:name) { |n| "Folder #{n}" }
    path { Dir.mktmpdir("archyve-folder-source") }
    sync_interval_minutes { 60 }
  end
end
