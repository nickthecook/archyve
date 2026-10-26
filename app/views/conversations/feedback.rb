# frozen_string_literal: true

# A finished turn's rating and comment: controls for whoever asked, the record
# of them for anyone else reading.
#
# Rendered inside Views::Conversations::Message, so it is helper-free for the
# same reason. Its forms carry no authenticity token — there is no session to
# take one from on the streaming path — and rely on Turbo sending the page's
# own as a header.
class Views::Conversations::Feedback < Components::Base
  LABELS = Views::Conversations::RatingIcon::LABELS

  def self.dom_id(message) = ActionView::RecordIdentifier.dom_id(message, :feedback)

  def initialize(message:, editable:)
    @message = message
    @feedback = message.feedback
    @editable = editable
  end

  def view_template
    return if !@editable && @feedback.nil?

    div(id: self.class.dom_id(@message), class: "flex flex-col gap-2", data: { controller: "reveal" }) do
      div(class: "flex items-center gap-1") do
        @editable ? controls : recorded_rating
      end
      saved_comment
      comment_form if @editable
    end
  end

  private

  def rating = @feedback&.rating&.to_sym

  def controls
    LABELS.each_key { thumb(it) }
    button(
      type: "button", aria_expanded: "false",
      data: { reveal_target: "toggle", action: "reveal#toggle" },
      class: "ml-1 rounded px-1.5 py-1 text-xs text-faint hover:text-fg transition-colors"
    ) { @feedback&.comment ? "Edit comment" : "Comment" }
  end

  # Pressing the chosen thumb again takes the rating back.
  def thumb(choice)
    pressed = rating == choice
    form(action: path, method: "post", class: "contents") do
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "rating", value: pressed ? "" : choice.to_s)
      button(
        type: "submit", aria_pressed: pressed.to_s, aria_label: LABELS[choice], title: LABELS[choice],
        class: "grid h-7 w-7 place-items-center rounded transition-colors " \
               "#{pressed ? 'bg-accent/10 text-accent' : 'text-faint hover:text-fg'}"
      ) { render Views::Conversations::RatingIcon.new(choice) }
    end
  end

  def recorded_rating
    return if rating.nil?

    span(class: "grid h-7 w-7 place-items-center text-accent", title: LABELS[rating]) do
      render Views::Conversations::RatingIcon.new(rating)
      span(class: "sr-only") { LABELS[rating] }
    end
  end

  def saved_comment
    return if @feedback&.comment.nil?

    p(class: "border-l-2 border-line pl-3 text-sm text-muted break-words whitespace-pre-wrap") { @feedback.comment }
  end

  def comment_form
    form(action: path, method: "post", hidden: true, data: { reveal_target: "panel" }, class: "flex flex-col gap-2") do
      input(type: "hidden", name: "_method", value: "patch")
      textarea(
        name: "comment", rows: "2", maxlength: Feedback::COMMENT_LIMIT, aria_label: "Comment on this answer",
        placeholder: "What was right or wrong with this answer?",
        data: {
          reveal_target: "field", controller: "autogrow submit-on-enter",
          action: "input->autogrow#resize focus->autogrow#resize keydown.enter->submit-on-enter#submit " \
                  "keydown.ctrl+enter->submit-on-enter#submit keydown.meta+enter->submit-on-enter#submit"
        },
        class: "w-full resize-none rounded border border-line bg-ink/60 px-3 py-2 text-sm text-fg " \
               "placeholder:text-faint outline-none focus:border-accent transition-colors"
      ) { @feedback&.comment }
      div(class: "flex gap-2") do
        button(type: "submit", class: button_class(:solid)) { "Save comment" }
        button(type: "button", data: { action: "reveal#toggle" }, class: button_class(:quiet)) { "Cancel" }
      end
    end
  end

  def path
    Rails.application.routes.url_helpers.conversation_message_feedback_path(@message.conversation_id, @message)
  end
end
