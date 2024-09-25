class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[show update destroy update_collections]

  # GET /conversations or /conversations.json
  def index
    @conversations = current_user.conversations
  end

  # GET /conversations/1 or /conversations/1.json
  def show
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("conversation", partial: "conversation") }
      format.html do
        @conversations = current_user.conversations
        render :index
      end
    end
  end

  # rubocop:disable Metrics/AbcSize
  # POST /conversations or /conversations.json
  def create
    unless Setting.chat_model && Setting.embedding_model && Setting.summarization_model
      return redirect_to(
        conversations_path,
        alert: "Please ask your admin to set the chat model, embedding model and summarization model in the admin UI."
      )
    end

    @conversation = Conversation.new
    @conversation.user = current_user
    @conversation.model_config ||= Setting.chat_model
    @conversation.title ||= "New conversation"
    @conversation.search_collections = Setting.get(:search_collections, target: current_user)
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
    update_user_settings

    respond_to do |format|
      if @conversation.update(conversation_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@conversation),
            partial: "conversation_list_item",
            locals: { conversation: @conversation, selected: @conversation }
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
  # rubocop:enable Metrics/AbcSize

  # DELETE /conversations/1 or /conversations/1.json
  def destroy
    @conversation.destroy!
    respond_to do |format|
      format.turbo_stream { redirect_to conversations_path, notice: "Conversation was successfully destroyed." }
      format.html { redirect_to conversations_url, notice: "Conversation was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def update_collections
    collections = Collection.find(params[:collection_ids])

    @conversation.collections << collections
    @conversation.save!
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id] || params[:conversation_id])
  end

  def conversation_params
    updated_params = params.require(:conversation).permit(:title, :model_config_id, :search_collections)
    updated_params[:model_config_id] = updated_params[:model_config_id].to_i if params.include?(:model_config_id)

    updated_params
  end

  def update_user_settings
    return if Setting.get(:search_collections, target: current_user) == search_param

    Setting.set(:search_collections, search_param, target: current_user)
  end

  def search_param
    @search_param ||= conversation_params[:search_collections] == "1"
  end
end
