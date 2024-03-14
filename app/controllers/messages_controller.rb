class MessagesController < ApplicationController
  before_action :set_message, except: [:create]
  before_action :set_conversation

  def create
    @message = Message.new(message_params)
    @message.author = current_user
    @message.save!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append(:messages, partial: "message", locals: { message: @message }),
          turbo_stream.replace(:message_form, partial: "messages/form")
        ]
      end
      format.html do
        render @message.conversation
      end

      ResponderJob.perform_async(@message.id)
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
