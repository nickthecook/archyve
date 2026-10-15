# frozen_string_literal: true

# The way into chat: pick what to draw on, ask the first question.
#
# Starting a chat and configuring one are the same act, because the scope is
# fixed once the conversation exists — there is nothing to set up afterwards,
# so there is no setup screen. Past conversations sit below the rule as this
# page's content.
class Views::Conversations::Index < Views::Base
  def initialize(conversations:, collections:, models: [], model: nil, scope: nil, unavailable: nil)
    @conversations = conversations
    @collections = collections
    @models = models
    @model = model
    @scope = scope
    @unavailable = unavailable
  end

  def view_template
    heading
    unavailable_panel if @unavailable
    composer
    render Views::Rule.new
    @conversations.any? ? list : empty
  end

  private

  def page_title = "Chat"

  def heading
    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Chat" }
      p(class: "mt-1 text-sm text-muted") do
        "Ask your archive a question. Retrieval runs as a tool the model calls, and every answer shows what it read."
      end
    end
  end

  def unavailable_panel
    div(class: "mb-6 rounded border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300") { @unavailable }
  end

  def composer
    form(
      action: conversations_path, method: "post",
      data: {
        controller: "composer",
        action: "keydown.ctrl+enter@document->composer#submit keydown.meta+enter@document->composer#submit"
      },
      class: "flex flex-col gap-3 rounded-lg border border-line-2 bg-ink/60 p-4"
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      textarea(
        name: "message", rows: "3", autocomplete: "off",
        placeholder: "What do you want to know?",
        data: {
          composer_target: "field",
          action: "input->composer#autogrow keydown.enter->composer#submit"
        },
        class: "w-full resize-none overflow-y-auto max-h-72 bg-transparent text-[0.95rem] " \
               "text-fg placeholder:text-faint outline-none"
      )
      div(class: "flex flex-wrap items-center gap-3 border-t border-line/60 pt-3") do
        scope_picker
        model_picker(@model)
        button(
          type: "submit", disabled: @unavailable.present?,
          class: "ml-auto rounded bg-accent px-4 py-2 text-sm font-semibold text-void hover:bg-accent-dim transition-colors"
        ) { "Start chat" }
      end
    end
  end

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

  def model_picker(selected)
    render Views::Conversations::ModelPicker.new(models: @models, selected: selected)
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

  def list
    h2(class: "mb-3 text-xs font-semibold uppercase tracking-[0.18em] text-muted") { "Earlier" }
    div(class: "space-y-2") { @conversations.each { row(it) } }
  end

  def row(conversation)
    div(class: "flex items-center gap-4 rounded-lg border border-line bg-ink/40 px-4 py-3 hover:border-line-2 transition-colors") do
      a(href: conversation_path(conversation), class: "min-w-0 flex-1") do
        span(class: "block truncate text-sm text-fg") { conversation.title.presence || "Untitled chat" }
        span(class: "mt-0.5 block text-xs text-faint") do
          "#{conversation.scope_label} · #{time_ago_in_words(conversation.updated_at)} ago"
        end
      end
      delete_button(conversation)
    end
  end

  def delete_button(conversation)
    form(action: conversation_path(conversation), method: "post", class: "shrink-0") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit", data: { turbo_confirm: "Delete this conversation?" },
        class: "rounded border border-line px-2.5 py-1 text-xs text-faint hover:text-red-300 hover:border-red-400/40 transition-colors"
      ) { "Delete" }
    end
  end

  def empty
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No conversations yet." }
    end
  end
end
