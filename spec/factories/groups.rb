FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Group #{n}" }
  end

  factory :group_user do
    association :group
    association :user
  end

  factory :collection_group do
    association :collection
    association :group
    access { "accessor" }

    trait :editor do
      access { "editor" }
    end

    trait :manager do
      access { "manager" }
    end
  end

  factory :source_group do
    association :source
    association :group
    access { "accessor" }

    trait :editor do
      access { "editor" }
    end

    trait :manager do
      access { "manager" }
    end
  end
end
