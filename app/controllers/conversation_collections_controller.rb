class ConversationCollectionsController < ApplicationController
  def create
    @collection = current_user.collections.find_by(id: params[:collection_ids])
    # TODO: lock this down to the user
    @conversation = Conversation.find(params[:conversation_id])

    @conversation.conversation_collections.destroy_all
    if @collection
      ConversationCollection.create!(collection: @collection, conversation: @conversation)
    end

    redirect_to conversation_path(@conversation)
  end
end
