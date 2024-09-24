module V1
  class ConversationsController < ApiController
    include Pageable

    before_action :set_conversation!, only: [:show]

    def index
      all_conversations = Conversation.order(updated_at: :desc)
      @pagy, @conversations = pagy(all_conversations, items:, page:)

      render json: { conversations: @conversations.map { |c| hash_for(c) }, page: page_data }, status: :ok
    end

    def show
      render json: { conversation: hash_for(@conversation) }, status: :ok
    end

    private

    def hash_for(conversation)
      {
        id: conversation.id,
        title: conversation.title,
        message_count: conversation.messages_count,
        model: conversation.model_config_id,
      }
    end

    def render_attributes
      %w[id title messages_count model_config_id]
    end

    def set_conversation!
      @conversation = Conversation.find(params[:id])

      render json: { error: "Conversation not found" }, status: :not_found if @conversation.nil?
    end
  end
end
