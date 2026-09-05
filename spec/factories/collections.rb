FactoryBot.define do
  factory :collection do
    sequence(:name) { |n| "Collection #{n}" }
    # slug is derived from name in a before_validation hook
  end
end
