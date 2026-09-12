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
      scope: Retrieval::Scope.from_params(params, user: Current.user),
      unavailable: unavailable_reason
    )
  end

  def show
    render Views::Conversations::Show.new(
      conversation: @conversation,
      messages: @conversation.messages.includes(segments: :hits),
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
      scope: scope_spec, inference_model: InferenceModel.default_chat, title: question.truncate(80)
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

  # Chat needs a tool-capable chat model and an embedding model, and says which
  # is missing rather than failing on the first question. Admins are told where
  # to fix it; everyone else is told it isn't ready, since only an admin can.
  def unavailable_reason
    return if InferenceModel.default_chat && InferenceModel.active_embedding

    if Current.user.admin?
      "Chat needs a tool-capable chat model and an embedding model. Add them under Settings › Inference."
    else
      "Chat isn't available yet — an admin needs to configure a chat model."
    end
  end
end
