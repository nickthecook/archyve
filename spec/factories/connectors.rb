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
end
