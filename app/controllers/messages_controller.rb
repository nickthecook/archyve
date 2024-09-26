class MessagesController < ApplicationController
  before_action :set_message, except: [:create]
  before_action :set_conversation
  before_action :validate_author!, only: [:regenerate]

  def create
    @message = create_message

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:message_form, partial: "messages/form"),
        ]
      end
      format.html do
        render @message.conversation
      end

      TitleSetterJob.perform_async(@conversation.id) if @conversation.messages.count == 1
      ReplyJob.perform_async(@message.id)
    end
  end

  def destroy
    @message.destroy!
    redirect_to conversation_path(@conversation)
  end

  def regenerate
    respond_to do |format|
      format.turbo_stream do
        ReplyJob.perform_async(@message.previous.id)
        @message.destroy!
      end
    end
  end

  private

  def create_message
    message = Message.new(message_params)
    message.author = current_user
    message.save!

    message
  end

  def validate_author!
    return unless @message.author.is_a?(User)

    flash.now[:alert] = "Cannot regenerate user message."
    render turbo_stream: turbo_stream.replace(user_dom_id("notice"), partial: "shared/notice")
  end

  def message_params
    params.permit(:content, :conversation_id)
  end

  def set_message
    @message = Message.find(params[:id] || params[:message_id])
  end

  def set_conversation
    @conversation = Conversation.find(message_params[:conversation_id])
  end
end
