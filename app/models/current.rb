class Current < ActiveSupport::CurrentAttributes
  attribute :session
  # Set instead of session when a request authenticates with a key.
  attribute :api_key

  # What an ApiCall recorded on this thread should be filed under — the chat
  # turn, usually. Carried here because ApiCalls::Recorder is Faraday middleware
  # and has no other way to learn what the call was for.
  attribute :api_call_traceable

  attribute :brand

  def user = session ? session.user : api_key&.principal
end
