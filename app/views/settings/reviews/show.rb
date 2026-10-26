# frozen_string_literal: true

# Someone else's chat, read-only. Nothing on this page may name or link to the
# person who had it.
class Views::Settings::Reviews::Show < Views::Base
  def initialize(conversation:, messages:)
    @conversation = conversation
    @messages = messages
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Review", settings_review_path], title)
    render Views::Conversations::Transcript.new(conversation: @conversation, messages: @messages, editable: false)
  end

  private

  def title = @conversation.title.presence || "Untitled chat"
  def page_title = title
end
