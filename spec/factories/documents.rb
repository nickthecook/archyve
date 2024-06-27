FactoryBot.define do
  factory :document do
    chunks { [] }
    user { association(:user) }
    collection { association(:collection) }
    filename { Faker::File.file_name(ext: "pdf") }
    state { :embedded }
    vector_id { nil } # TODO: we probably don't need this
  end
end
