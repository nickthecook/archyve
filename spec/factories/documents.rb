FactoryBot.define do
  factory :document do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    filename { "gnu_manifesto.md" }
    state { :chunked }
    vector_id { nil } # TODO: we probably don't need this
    chunking_profile { association(:chunking_profile) }

    trait :with_file do
      file { Rails.root.join("spec/fixtures/files/small_doc.md") }
    end
  end
  factory :document_from_web, parent: :document do
    trait :with_file do
      filename { "web.html" }
      link { "https://web.org" }
      file { Rails.root.join("spec/fixtures/files/small_page.html") }
    end
  end
end
