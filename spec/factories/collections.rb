FactoryBot.define do
  factory :collection do
    name { Faker::Hipster.word.capitalize }
    slug { name.underscore }
    embedding_model { association(:model_config, embedding: true) }
  end
end
