FactoryBot.define do
  factory :source_sync do
    association :source
    started_at { Time.current }
    finished_at { Time.current }
    # Derived from started_at, not Time.current, so a run built as old is old in
    # the way SourceSync#stalled? actually measures.
    last_progress_at { started_at }
    status { "completed" }
  end
end
