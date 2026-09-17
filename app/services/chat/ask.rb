# frozen_string_literal: true

module Chat
  # Records a question, opens the turn that will answer it, and sets the answer
  # going.
  #
  # Both controllers that can ask something go through here, so the three parts —
  # the question, the empty answer, and the job — can't drift apart.
  #
  # ## Why the assistant's turn is created here, in the request
  #
  # It would be more natural to let the job create the turn it is about to
  # write. That is what this did, and it raced: the job would create the message
  # and broadcast an *append* to put it on the page, and if that append fired
  # between the redirect's page render and the browser's ActionCable
  # subscription being confirmed, it landed nowhere — there is no replay — and
  # every later broadcast was a replace aimed at an element the page never got.
  # The answer streamed into the void until the person reloaded.
  #
  # Created here, the row exists before the redirect, so the page we redirect to
  # always renders it, spinner and all. Chat::Turn then only ever *replaces* an
  # element the page is guaranteed to have, and because a replace carries the
  # whole current state, a broadcast lost in that same window costs nothing —
  # the next tick, a hundred milliseconds later, carries the same news.
  #
  # The enqueue sits outside the transaction on purpose. solid_queue runs in
  # another process, and a job enqueued mid-transaction can be picked up before
  # the rows it names are visible, which fails as a mystifying RecordNotFound
  # under load and never in development.
  class Ask
    def self.call(conversation, question, model: nil) = new(conversation, question, model:).call

    def initialize(conversation, question, model: nil)
      @conversation = conversation
      @question = question
      @model = model
    end

    def call
      question_message = nil
      answer = nil

      @conversation.transaction do
        # Switching model is sticky: it holds for this question and every one
        # after it, until the person switches again. The alternative — a switch
        # that lasts one turn and silently reverts — is a setting that lies
        # about itself the moment you look away from it.
        @conversation.update!(inference_model: @model) if @model

        position = @conversation.next_message_position
        question_message = @conversation.messages.create!(role: :user, position: position)
        question_message.segments.create!(kind: :text, position: 1, content: @question)

        # Stamped with the model now rather than when the job picks this up, so
        # a turn that never happens can still say which model was asked — a
        # failed turn that can't name the model is a support question waiting to
        # be asked. Nil is an ordinary state (no chat model configured at all);
        # Chat::Responder says so on the turn rather than raising.
        answer = @conversation.messages.create!(
          role: :assistant, position: position + 1,
          inference_model: @conversation.inference_model || InferenceModel.default_chat
        )
      end

      RespondJob.perform_later(question_message, answer)
      question_message
    end
  end
end
