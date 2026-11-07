# frozen_string_literal: true

# Just the button, not its form: Message broadcasts this from a job, where there
# is no request to issue an authenticity token, so the form stays put with the
# token the page was rendered with.
class Views::Conversations::DeleteButton < Components::Base
  ROW = "rounded border border-line px-2.5 py-1 text-xs text-faint transition-colors " \
        "enabled:hover:text-red-300 enabled:hover:border-red-400/40"

  def self.dom_id(conversation) = ActionView::RecordIdentifier.dom_id(conversation, :delete)

  # `weight` is :row in the chat list, :page on the conversation itself.
  def initialize(conversation:, answering:, weight: :row)
    @conversation = conversation
    @answering = answering
    @weight = weight
  end

  def view_template
    button(
      id: self.class.dom_id(@conversation), type: "submit", disabled: @answering,
      title: ("Still answering" if @answering),
      data: { turbo_confirm: "Delete this conversation? This can't be undone." },
      class: [style, "disabled:opacity-40 disabled:hover:bg-transparent"]
    ) { "Delete" }
  end

  private

  def style = @weight == :page ? button_class(:danger) : ROW
end
