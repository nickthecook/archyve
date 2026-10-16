FactoryBot.define do
  factory :inference_model do
    association :inference_server
    sequence(:name) { |n| "llama3.1:#{n}b" }
    kind { :chat }

    trait :tools do
      supports_tools { true }
    end

    # Dimensions have to match the embeddings column or the model is invalid,
    # which is the point of the validation — so the trait doesn't let you forget.
    factory :embedding_model do
      name { "nomic-embed-text:v1.5" }
      kind { :embedding }
      dimensions { Embedding::DIMENSIONS }
    end
  end
end
