FactoryBot.define do
  factory :document do
    association :connector
    sequence(:external_id) { |n| "ext-#{n}" }
    title { "Sample Document" }
    content_type { "text/markdown" }
    status { "pending" }

    trait :with_file do
      after(:build) do |document|
        document.file.attach(
          io: StringIO.new("# Title\n\nBody text."),
          filename: "sample.md",
          content_type: "text/markdown"
        )
      end
    end
  end
end
