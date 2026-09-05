FactoryBot.define do
  factory :chunk do
    association :document
    sequence(:position)
    content { "Some chunk content." }
    structure { {} }
  end
end
