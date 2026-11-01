class FeedbacksController < ApplicationController
  require_role :visitor

  # Each form posts only its own field — the thumbs a rating, the comment box a
  # comment — so saving one never clears the other.
  def update
    message = answered_message
    feedback = message.feedback || message.build_feedback
    feedback.rating = rating if params.key?(:rating)
    feedback.comment = params[:comment].to_s if params.key?(:comment)
    return head(:unprocessable_content) if feedback.invalid?

    feedback.empty? ? feedback.destroy : feedback.save!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: swap(message) }
      format.html { redirect_to conversation_path(message.conversation, anchor: Views::Conversations::Message.dom_id(message)) }
    end
  end

  private

  def answered_message
    Current.user.conversations.find(params[:conversation_id])
      .messages.assistant.where.not(completed_at: nil).find(params[:message_id])
  end

  def rating = params[:rating].presence_in(Feedback.ratings.keys)

  def swap(message)
    component = Views::Conversations::Feedback.new(message: message.reload, editable: true)
    turbo_stream.replace(component.class.dom_id(message), html: render_to_string(component))
  end
end
