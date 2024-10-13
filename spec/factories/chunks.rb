FactoryBot.define do
  factory :chunk do
    document { association(:document) }
    vector_id { SecureRandom.uuid }
    content { Faker::Lorem.sentence(word_count: 10) }
    embedding_content { Faker::Lorem.sentence(word_count: 16) }
  end
  factory :chunk_from_web, parent: :chunk do
    document { association(:document_from_web) } #, link: Faker::Internet.url) }
  end
end
