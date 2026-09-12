# frozen_string_literal: true

module Chat
  # Records a question and sets the answer going.
  #
  # Both controllers that can ask something go through here, so the two halves —
  # persisting the turn and enqueuing the job — can't drift apart.
  #
  # The enqueue sits outside the transaction on purpose. solid_queue runs in
  # another process, and a job enqueued mid-transaction can be picked up before
  # the row it names is visible, which fails as a mystifying RecordNotFound
  # under load and never in development.
  class Ask
    def self.call(conversation, question) = new(conversation, question).call

    def initialize(conversation, question)
      @conversation = conversation
      @question = question
    end

    def call
      message = nil

      @conversation.transaction do
        message = @conversation.messages.create!(
          role: :user, position: @conversation.next_message_position
        )
        message.segments.create!(kind: :text, position: 1, content: @question)
      end

      RespondJob.perform_later(message)
      message
    end
  end
end
