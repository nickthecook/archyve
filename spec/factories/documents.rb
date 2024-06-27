FactoryBot.define do
  factory :document do
    chunks { association_list(:chunk, 3) }
    user { association(:user) }
    collection { association(:collection) }
    filename { Faker::File.file_name(ext: "pdf") }
    state { :embedded }
    vector_id { nil } # TODO: we probably don't need this
  end
end
