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
    def self.call(conversation, question, model: nil) = new(conversation, question, model:).call

    def initialize(conversation, question, model: nil)
      @conversation = conversation
      @question = question
      @model = model
    end

    def call
      message = nil

      @conversation.transaction do
        # Switching model is sticky: it holds for this question and every one
        # after it, until the person switches again. The alternative — a switch
        # that lasts one turn and silently reverts — is a setting that lies
        # about itself the moment you look away from it.
        @conversation.update!(inference_model: @model) if @model

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
