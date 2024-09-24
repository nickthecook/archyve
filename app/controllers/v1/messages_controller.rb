module V1
  class MessagesController < ApiController
    include Pageable

    before_action :set_conversation!
    before_action :set_message!, only: [:show]

    def index
      @pagy, @messages = pagy(@conversation.messages, items:, page:)
      render json: { messages: @messages.map { |message| body_for(message) }, page: page_data }
    end

    def show
      render json: body_for(@message)
    end

    private

    def body_for(message)
      body = message.attributes.to_h.slice(*render_attributes)
      remove_id_suffix_from("author", body)
      remove_id_suffix_from("conversation", body)

      body
    end

    def set_message!
      @message = Message.find(params[:id])

      render json: { error: "Message not found" }, status: :not_found if @message.nil?
    end

    def set_conversation!
      @conversation = Conversation.find_by(id: params[:conversation_id])

      render json: { error: "Conversation not found" }, status: :not_found if @conversation.nil?
    end

    def render_attributes
      %w[id content raw_content statistics error prompt created_at updated_at author_type author_id conversation_id]
    end
  end
end
