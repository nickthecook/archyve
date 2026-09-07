FactoryBot.define do
  factory :source_sync do
    association :source
    started_at { Time.current }
    finished_at { Time.current }
    status { "completed" }
  end
end
