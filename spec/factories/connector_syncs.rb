FactoryBot.define do
  factory :connector_sync do
    association :connector
    started_at { Time.current }
    finished_at { Time.current }
    status { "completed" }
  end
end
