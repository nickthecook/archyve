module V1
  class ConversationsController < ApiController
    include Pagy::Backend

    before_action :set_conversation!, only: [:show]

    def index
      all_conversations = Conversation.order(updated_at: :desc)
      @pagy, @conversations = pagy(all_conversations, items: count)

      render json: { conversations: @conversations.map { |c| hash_for(c) } }, status: :ok
    end

    def show
      render json: { conversation: hash_for(@conversation) }, status: :ok
    end

    private

    def count
      if params[:count]
        params[:count].to_i
      else
        20
      end
    end

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
