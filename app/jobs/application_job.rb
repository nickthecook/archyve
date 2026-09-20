class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Every job here is work *on* a record, so one whose records are gone has
  # nothing left to do. Deleting a document while its pipeline job is still
  # queued is now an ordinary thing to do, and should read as one rather than as
  # a failed job.
  discard_on ActiveJob::DeserializationError
end
