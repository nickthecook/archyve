class MessagesController < ApplicationController
  before_action :set_message
  before_action :set_conversation

  def create
    @message = Message.new(message_params)
    @message.user = current_user
    @message.save!
  end

  def destroy
    @message.destroy!
    redirect_to conversation_path(@conversation)
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end

  def set_message
    @message = Message.find(params[:id])
  end

  def set_conversation
    @conversation = Conversation.find(@message.conversation_id)
  end
end
