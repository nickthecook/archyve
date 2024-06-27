class ConversationCollectionsController < ApplicationController
  before_action :set_conversation, :set_collection

  def create
    @conversation.conversation_collections.destroy_all
    ConversationCollection.create!(collection: @collection, conversation: @conversation) if @collection

    respond_to do |format|
      format.turbo_stream { @conversation.update_form }
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def set_collection
    @collection = current_user.collections.find(params[:collection_ids]) if params[:collection_ids]
  end
end
