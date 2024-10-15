FactoryBot.define do
  factory :document do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    state { :chunked }
    vector_id { nil } # TODO: we probably don't need this
    chunking_profile { association(:chunking_profile) }

    filename { "gnu_manifesto.md" }

    trait :with_file do
      file { Rails.root.join("spec/fixtures/files/small_doc.md") }
    end
  end
  factory :document_from_web, class: 'Document' do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    state { :chunked }
    vector_id { nil } # TODO: we probably don't need this
    chunking_profile { association(:chunking_profile) }

    filename { "web.html" }
    link { Faker::Internet.url }

    trait :with_file do
      file { Rails.root.join("spec/fixtures/files/small_page.html") }
    end
  end
end
