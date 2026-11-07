# frozen_string_literal: true

# One conversation: what it's drawing on, the transcript, and the box to ask
# the next thing.
class Views::Conversations::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(conversation:, messages:, models:, unavailable: nil)
    @conversation = conversation
    @messages = messages
    @models = models
    @unavailable = unavailable
  end

  def view_template
    back_link
    # Assistant turns fill in here as they are produced. The turn itself was
    # rendered above by this very request — Chat::Ask opens it before the
    # redirect — so Chat::Turn only ever replaces it as the model streams,
    # searches, and streams again.
    turbo_stream_from(@conversation)
    render Views::Conversations::Transcript.new(conversation: @conversation, messages: @messages, editable: true)
    composer
  end

  private

  def page_title = @conversation.title.presence || "Chat"

  def back_link
    render Views::Breadcrumb.new(*trail, @conversation.title.presence || "Untitled chat") { delete_button }
  end

  def delete_button
    form(action: conversation_path(@conversation), method: "post") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      render Views::Conversations::DeleteButton.new(
        conversation: @conversation, answering: @messages.any?(&:in_progress?), weight: :page
      )
    end
  end

  # Where the chat was started from.
  def trail
    return [["Settings", settings_path], ["Admin", settings_admin_path]] if @conversation.agent.admin_support?

    [["Chat", conversations_path]]
  end

  def ask_placeholder
    name = @conversation.agent.name
    return "Ask #{name}…" unless @conversation.agent.searches_archive?
    return "Ask #{name} about #{@conversation.scope_label}…" if @conversation.searches_archive?

    "Ask #{name} anything — nothing here is searched"
  end

  # The meter sits in the composer's own block rather than before it, so the
  # gap above the box is the same whether or not there is a reading to show —
  # see Views::Conversations::ContextMeter, which renders an empty element when
  # there isn't.
  def composer
    div(class: "mt-10") do
      render Views::Conversations::ContextMeter.new(conversation: @conversation)
      ask
    end
  end

  def ask
    form(
      action: conversation_messages_path(@conversation), method: "post",
      data: {
        controller: "composer",
        action: "keydown.ctrl+enter@document->composer#submit keydown.meta+enter@document->composer#submit"
      },
      class: "flex flex-col gap-3 rounded-lg border border-line-2 bg-ink/60 p-4"
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      textarea(
        name: "message", rows: "2", autocomplete: "off",
        placeholder: ask_placeholder,
        data: {
          composer_target: "field",
          action: "input->composer#autogrow keydown.enter->composer#submit"
        },
        class: "w-full resize-none overflow-y-auto max-h-72 bg-transparent text-[0.95rem] " \
               "text-fg placeholder:text-faint outline-none"
      )
      div(class: "flex flex-wrap items-center gap-3") do
        span(class: "inline-flex items-center rounded-full border border-line px-2.5 py-1 text-xs text-fg") do
          @conversation.agent.name
        end
        if @conversation.agent.searches_archive?
          render Views::ScopeChip.new(label: @conversation.scope_label, searching: @conversation.searches_archive?)
        end
        render Views::Conversations::ModelPicker.new(models: @models, selected: @conversation.inference_model)
        button(
          type: "submit", disabled: @unavailable.present?,
          class: "ml-auto rounded bg-accent px-4 py-2 text-sm font-semibold text-void hover:bg-accent-dim transition-colors"
        ) { "Send" }
      end
    end
    render Views::Disclaimer.new(css: "mt-2 text-center text-xs text-faint")
  end
end
