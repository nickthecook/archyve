FactoryBot.define do
  factory :chunk do
    document { association(:document) }
    vector_id { SecureRandom.uuid }
    content { Faker::Lorem.sentence(word_count: 10) }
    embedding_content { Faker::Lorem.sentence(word_count: 16) }
  end

  factory :chunk_from_web, class: 'Chunk' do
    document { association(:document_from_web) }
    vector_id { SecureRandom.uuid }
    content { Faker::Lorem.sentence(word_count: 10) }
    embedding_content { Faker::Lorem.sentence(word_count: 16) }
  end
end
