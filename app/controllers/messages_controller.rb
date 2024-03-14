class MessagesController < ApplicationController
  before_action :set_message, except: [:create]
  before_action :set_conversation

  def create
    @message = Message.new(message_params)
    @message.user = current_user
    @message.save!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.append("messages", partial: "message", locals: { message: @message }) }
      format.html do
        render @message.conversation
      end
    end
  end

  def destroy
    @message.destroy!
    redirect_to conversation_path(@conversation)
  end

  private

  def message_params
    params.permit(:content, :conversation_id)
  end

  def set_message
    @message = Message.find(params[:id])
  end

  def set_conversation
    @conversation = Conversation.find(message_params[:conversation_id])
  end
end
