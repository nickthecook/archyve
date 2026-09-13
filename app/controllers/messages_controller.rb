class MessagesController < ApplicationController
  require_role :user

  # Asking a follow-up. The answer doesn't come back in this response — it
  # arrives over the cable as the model produces it — so this redirects
  # straight back to the transcript, where the new turn is already waiting with
  # a spinner in it.
  def create
    conversation = Current.user.conversations.find(params[:conversation_id])
    question = params[:message].to_s.strip

    Chat::Ask.call(conversation, question, model: chosen_model) if question.present?

    redirect_to conversation_path(conversation)
  end

  private

  # Looked up through `for_chat` rather than by id alone: the id arrives in a
  # form field, and a model that can't call tools can't search the archive.
  # An unusable id is ignored rather than refused — the question still stands,
  # and the conversation keeps the model it already had.
  def chosen_model
    id = params[:inference_model_id].presence
    id && InferenceModel.for_chat.find_by(id: id)
  end
end
