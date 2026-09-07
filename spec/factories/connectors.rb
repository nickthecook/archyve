FactoryBot.define do
  # Connector is an STI base with a NOT NULL `type`, so the default factory
  # builds a concrete subclass. ManualUpload is the only one so far; add named
  # factories for other connector types as they arrive.
  factory :connector, class: "Connectors::ManualUpload" do
    sequence(:name) { |n| "Connector #{n}" }

    factory :manual_upload_connector do
      name { "Manual Upload" }
    end
  end

  # Points at a real temporary directory, since the connector validates that its
  # path exists and is readable. Pass `path` to point it at a fixture tree.
  factory :folder_connector, class: "Connectors::Folder" do
    sequence(:name) { |n| "Folder #{n}" }
    path { Dir.mktmpdir("archyve-folder-connector") }
    sync_interval_minutes { 60 }
  end
end
