FactoryBot.define do
  factory :embedding do
    association :chunk
    embedding_model { Embedding::DEFAULT_MODEL }
    embedding { Array.new(Embedding::DIMENSIONS) { rand } }
  end
end
