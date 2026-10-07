class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true

  # What an ApiCall recorded on this thread should be filed under — the chat
  # turn, usually. Carried here because ApiCalls::Recorder is Faraday middleware
  # and has no other way to learn what the call was for.
  attribute :api_call_traceable
end
