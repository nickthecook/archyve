class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show edit update destroy ]

  # GET /conversations or /conversations.json
  def index
    @conversations = Conversation.all
  end

  # GET /conversations/1 or /conversations/1.json
  def show
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("conversation", partial: "conversation") }
      format.html do
        @conversations = Conversation.all
        render :index
      end
    end
  end

  # POST /conversations or /conversations.json
  def create
    @conversation = Conversation.new
    @conversation.user = current_user
    @conversation.model_config ||= ModelConfig.first
    @conversation.title ||= "New conversation"
    @conversation.save!

    respond_to do |format|
      if @conversation.save
        format.html { redirect_to conversation_url(@conversation) }
        format.json { render :show, status: :created, location: @conversation }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @conversation.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /conversations/1 or /conversations/1.json
  def update
    respond_to do |format|
      if @conversation.update(conversation_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@conversation),
            partial: "conversation_list_item",
            locals: { conversation: @conversation }
          )
        end
        format.html { redirect_to conversation_url(@conversation) }
        format.json { render :show, status: :ok, location: @conversation }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @conversation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /conversations/1 or /conversations/1.json
  def destroy
    @conversation.destroy!

    respond_to do |format|
      format.html { redirect_to conversations_url, notice: "Conversation was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_conversation
      @conversation = Conversation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def conversation_params
      updated_params = params.require(:conversation).permit(:title, :model_config_id)
      updated_params[:model_config_id] = updated_params[:model_config_id].to_i if params.include?(:model_config_id)

      updated_params
    end
end
