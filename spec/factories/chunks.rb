FactoryBot.define do
  factory :chunk do
    document { association(:document) }
    vector_id { SecureRandom.uuid }
    excerpt { Faker::Lorem.sentence(word_count: 10) }
    headings { Faker::Lorem.sentence(word_count: 10) }
    surrounding_content { Faker::Lorem.sentence(word_count: 20) }
    location_summary { Faker::Lorem.sentence(word_count: 10) }
    embedding_content { Faker::Lorem.sentence(word_count: 40) }
  end
end
