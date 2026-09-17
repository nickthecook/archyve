module Chat
  # Answers one message, off the request. A turn can take a minute — the model
  # streams, stops to search, streams again — and the page follows it over the
  # cable rather than holding a connection open waiting for it.
  class RespondJob < ApplicationJob
    queue_as :default

    # One turn at a time per conversation. Two answers streaming into the same
    # transcript would interleave their segments and fight over positions;
    # a second question asked mid-answer waits its turn instead.
    limits_concurrency key: ->(message, _answer) { message.conversation_id }, to: 1, duration: 10.minutes

    # The answer's message row already exists — Chat::Ask opened it in the
    # request, so the page the person is looking at has it. See the note there.
    def perform(user_message, answer)
      Responder.call(user_message, answer)
    end
  end
end
