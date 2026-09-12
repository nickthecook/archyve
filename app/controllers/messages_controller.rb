class MessagesController < ApplicationController
  require_role :user

  # Asking a follow-up. The answer doesn't come back in this response — it
  # arrives over the cable as the model produces it — so this redirects
  # straight back to the transcript, where the new turn is already waiting with
  # a spinner in it.
  def create
    conversation = Current.user.conversations.find(params[:conversation_id])
    question = params[:message].to_s.strip

    Chat::Ask.call(conversation, question) if question.present?

    redirect_to conversation_path(conversation)
  end
end
