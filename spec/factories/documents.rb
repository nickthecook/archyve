FactoryBot.define do
  factory :document do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    filename { "gnu_manifesto.md" }
    state { :chunked }
    vector_id { nil } # TODO: we probably don't need this
    chunking_profile { association(:chunking_profile) }
  end
end

FactoryBot.define do
  factory :documentx, class: "Document" do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    filename { "gnu_manifesto.md" }
    state { :chunked }
    vector_id { nil } # TODO: we probably don't need this
    chunking_profile { association(:chunking_profile) }
    file { Rails.root.join("spec/fixtures/files/small_doc.md") }
  end
end
