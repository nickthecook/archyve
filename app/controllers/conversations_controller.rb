class ConversationsController < ApplicationController
  require_role :user

  # A conversation is private to whoever had it. Every lookup goes through the
  # signed-in user's own association rather than Conversation.find + a check,
  # so there is no path where forgetting the check is possible — someone else's
  # id is a 404, which is also the honest answer to "does this exist".
  before_action :load_conversation, only: [:show, :destroy]

  def index
    render Views::Conversations::Index.new(
      conversations: Current.user.conversations.recent.limit(30),
      collections: readable_collections,
      models: choosable_models,
      model: InferenceModel.default_chat,
      scope: Retrieval::Scope.from_params(params, user: Current.user),
      unavailable: unavailable_reason
    )
  end

  def show
    render Views::Conversations::Show.new(
      conversation: @conversation,
      messages: @conversation.messages.includes(:inference_model, segments: { hits: :document }),
      models: choosable_models,
      unavailable: unavailable_reason
    )
  end

  # Starting a chat is choosing a scope and asking the first question, in one
  # move — the scope can't be changed later, so there is nothing to configure
  # before the conversation exists.
  def create
    question = params[:message].to_s.strip
    return redirect_to conversations_path, alert: "Ask something to start a chat." if question.blank?

    conversation = Current.user.conversations.create!(
      scope: scope_spec, inference_model: chosen_model || InferenceModel.default_chat,
      title: question.truncate(80)
    )
    Chat::Ask.call(conversation, question)
    redirect_to conversation_path(conversation)
  end

  def destroy
    @conversation.destroy!
    redirect_to conversations_path, notice: "Deleted that conversation."
  end

  private

  def load_conversation
    @conversation = Current.user.conversations.find(params[:id])
  end

  # The scope, as the wire format the search page already speaks — so "chat
  # about these results" can hand its params straight over.
  def scope_spec
    { "c" => Array(params[:c]).reject(&:blank?), "doc" => params[:doc].presence }.compact_blank
  end

  def readable_collections = Collection.readable_by(Current.user).order(:name)

  # The models chat may offer, which is not every model configured: retrieval is
  # a tool the model calls, so one that can't call tools can't do this job at
  # all. See InferenceModel.for_chat.
  def choosable_models = InferenceModel.choosable_for_chat

  # A model the person picked, if it is one they could have been offered.
  # Looked up through `for_chat` rather than by id alone: the id arrives in a
  # form field, and nothing stops someone posting the id of the embedding model.
  def chosen_model
    id = params[:inference_model_id].presence
    id && InferenceModel.for_chat.find_by(id: id)
  end

  # Shared with the landing, whose bar asks a question too — see Chat::Availability.
  def unavailable_reason = Chat::Availability.reason_for(Current.user)
end
