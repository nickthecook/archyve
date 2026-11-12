FactoryBot.define do
  factory :embedding do
    association :chunk
    # The model id is a free-text record of what produced this vector, not a
    # foreign key, so the factory doesn't need an InferenceModel to exist.
    embedding_model { "nomic-embed-text:v1.5" }
    vector { Array.new(768) { rand } }
  end
end
