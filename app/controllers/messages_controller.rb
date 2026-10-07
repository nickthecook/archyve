class MessagesController < ApplicationController
  require_role :user

  # Asking a follow-up. The answer doesn't come back in this response — it
  # arrives over the cable as the model produces it — so this redirects
  # straight back to the transcript, where the new turn is already waiting with
  # a spinner in it.
  #
  # Anchored at the question just asked, rather than at the top of the page.
  # The redirect is a full page load, and on a phone a conversation of any
  # length then puts the new turn well below the fold — so the person who just
  # pressed Send is looking at the start of a chat they have already read, with
  # nothing on screen to say their message went anywhere. Landing on their own
  # question puts the answer where it is about to stream in, directly below it.
  def create
    conversation = Current.user.conversations.find(params[:conversation_id])
    question = params[:message].to_s.strip
    asked = Chat::Ask.call(conversation, question, model: chosen_model) if question.present?

    redirect_to conversation_path(conversation, anchor: asked && Views::Conversations::Message.dom_id(asked))
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
