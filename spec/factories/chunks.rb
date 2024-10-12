FactoryBot.define do
  factory :chunk do
    document { association(:document) }
    vector_id { SecureRandom.uuid }
    content { Faker::Lorem.sentence(word_count: 10) }
    embedding_content { Faker::Lorem.sentence(word_count: 16) }

    factory :chunk_from_web do
      document { association(:document, link: Faker::Internet.url) }
    end
  end
end
