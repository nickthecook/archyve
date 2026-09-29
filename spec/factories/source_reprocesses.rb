FactoryBot.define do
  factory :source_reprocess do
    association :source
    total { 0 }
  end
end
