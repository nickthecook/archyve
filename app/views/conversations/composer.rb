# frozen_string_literal: true

# The box that starts a chat with one agent. The scope picker only appears for
# an agent that searches the archive; there is nothing to narrow otherwise.
class Views::Conversations::Composer < Components::Base
  def initialize(agent:, models:, model: nil, collections: [], scope: nil, unavailable: nil, placeholder: nil)
    @agent = agent
    @models = models
    @model = model
    @collections = collections
    @scope = scope
    @unavailable = unavailable
    @placeholder = placeholder || "Ask #{agent.name}…"
  end

  def view_template
    form(
      action: conversations_path, method: "post",
      data: {
        controller: "composer",
        action: "keydown.ctrl+enter@document->composer#submit keydown.meta+enter@document->composer#submit"
      },
      class: "flex flex-col gap-3 rounded-lg border border-line-2 bg-ink/60 p-4"
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "agent", value: @agent.slug)
      textarea(
        name: "message", rows: "3", autocomplete: "off",
        placeholder: @placeholder,
        data: {
          composer_target: "field",
          action: "input->composer#autogrow keydown.enter->composer#submit"
        },
        class: "w-full resize-none overflow-y-auto max-h-72 bg-transparent text-[0.95rem] " \
               "text-fg placeholder:text-faint outline-none"
      )
      div(class: "flex flex-wrap items-center gap-3 border-t border-line/60 pt-3") do
        scope_picker if @agent.searches_archive?
        render Views::Conversations::ModelPicker.new(models: @models, selected: @model)
        button(
          type: "submit", disabled: @unavailable.present?,
          class: "ml-auto rounded bg-accent px-4 py-2 text-sm font-semibold text-void hover:bg-accent-dim transition-colors"
        ) { "Start chat" }
      end
    end
    render Views::Disclaimer.new(css: "mt-2 text-center text-xs text-faint")
  end

  private

  # Checkboxes rather than a select: the scope is a set, and the whole point is
  # that you can see what's in it without opening anything. Everything is ticked
  # to start with, because that is what the chat will actually search — a picker
  # that searched everything while showing nothing ticked was telling the
  # opposite of the truth. Untick to narrow; untick everything for a chat that
  # doesn't touch the archive at all.
  def scope_picker
    div(class: "flex flex-wrap items-center gap-2") do
      span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Draw on" }

      if @collections.any?
        # Posted whatever is ticked, so an unticked picker arrives as an empty
        # selection rather than as no selection at all — the difference between
        # searching nothing and searching everything. See
        # ConversationsController#scope_spec.
        input(type: "hidden", name: "c[]", value: "")
        @collections.each { |collection| scope_chip(collection) }
      else
        # No picker, so nothing to send: the chat draws on everything, which is
        # what an empty c[] would have quietly turned into a search of nothing.
        span(class: "text-xs text-faint") { "everything you can read, unless you narrow it" }
      end
    end
  end

  def scope_chip(collection)
    label(class: "inline-flex cursor-pointer items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted hover:border-line-2 hover:text-fg transition-colors") do
      input(
        type: "checkbox", name: "c[]", value: collection.slug,
        checked: checked?(collection),
        class: "accent-accent"
      )
      plain collection.name
    end
  end

  # No scope in the URL means nobody has narrowed anything yet, and the default
  # is the whole archive — so every box is ticked. A scope arriving from a
  # search link ticks exactly what that link named, including nothing.
  def checked?(collection)
    return true if @scope.nil?

    @scope.spec.fetch("c", []).include?(collection.slug)
  end
end
