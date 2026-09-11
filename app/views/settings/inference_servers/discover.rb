# frozen_string_literal: true

# What the server says it can run, ticked into Archyve.
#
# Discovery answers different amounts depending on the provider. Ollama's native
# API declares each model's capabilities, so kind, context window, dimensions
# and tool support all arrive filled in. An OpenAI-compatible /v1/models is a
# list of ids and nothing else, so those rows carry a kind picker instead —
# which is the honest rendering, not a gap.
class Views::Settings::InferenceServers::Discover < Views::Base
  def initialize(server:, discovered:, existing:, embedding_locked:, has_embedding_model:)
    @server = server
    @discovered = discovered
    @existing = existing
    @embedding_locked = embedding_locked
    @has_embedding_model = has_embedding_model
  end

  def view_template
    div(class: "mb-1 text-xs text-faint") do
      a(href: settings_inference_server_path(@server), class: "hover:text-muted transition-colors") { @server.name }
    end

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Models on #{@server.name}" }
      p(class: "mt-1 text-sm text-muted") { subtitle }
    end

    @discovered.any? ? picker : empty_state
  end

  private

  def page_title = "Models on #{@server.name}"

  def subtitle
    "#{@discovered.size} #{'model'.pluralize(@discovered.size)} reported. Tick the ones Archyve may use."
  end

  # The same list-filter controller the document picker and collections grid
  # use — a long model list is exactly the case it exists for.
  def picker
    form(
      action: import_settings_inference_server_path(@server),
      method: "post",
      class: "flex flex-col gap-4",
      data: { controller: "list-filter" }
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      input(
        type: "search",
        placeholder: "Filter models…",
        autocomplete: "off",
        data: { list_filter_target: "query", action: "input->list-filter#filter" },
        class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
               "outline-none focus:border-accent transition-colors"
      )

      div(class: "max-h-[28rem] overflow-y-auto rounded-lg border border-line bg-ink/40 divide-y divide-line") do
        @discovered.each { |model| row(model) }
      end

      p(class: "text-xs text-faint", data: { list_filter_target: "empty" }, hidden: true) { "No models match." }

      div(class: "flex items-center gap-3") do
        button(
          type: "submit",
          class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
        ) { "Import selected" }
        a(
          href: settings_inference_server_path(@server),
          class: "text-sm text-muted hover:text-fg transition-colors"
        ) { "Cancel" }
      end
    end
  end

  def row(model)
    already = @existing.include?(model.name)
    blocked = blocked_reason(model, already)

    label(
      class: "flex items-start gap-3 px-5 py-3.5 #{blocked ? 'opacity-50' : 'cursor-pointer hover:bg-ink/60'} transition-colors",
      data: { list_filter_target: "item", name: model.name.downcase }
    ) do
      input(
        type: "checkbox", name: "models[]", value: model.name,
        disabled: blocked.present?, class: "mt-0.5 accent-accent"
      )
      div(class: "min-w-0 flex-1") do
        div(class: "flex flex-wrap items-center gap-2") do
          span(class: "font-mono text-sm text-fg") { model.name }
          tag("tools") if model.supports_tools
          tag("#{model.dimensions}d") if model.dimensions
        end
        p(class: "mt-0.5 text-xs text-faint") { blocked || detail(model) }
        carried(model)
      end
      kind_control(model, blocked)
    end
  end

  # Why a row can't be ticked, or nil. Said out loud on the row rather than
  # leaving a checkbox that silently does nothing.
  def blocked_reason(model, already)
    return "Already imported." if already
    return unless model.kind.to_s == "embedding"
    return "Archyve already has an embedding model." if @has_embedding_model
    return unless @embedding_locked

    "The archive is already embedded — changing the embedding model needs a re-embed, which Archyve can't do yet."
  end

  def detail(model)
    parts = []
    parts << "#{ActiveSupport::NumberHelper.number_to_delimited(model.context_window)} token context" if model.context_window
    parts << "reported as an embedding model" if model.kind.to_s == "embedding"
    parts << "the server didn't say what this model is for" if model.kind.nil?
    parts.join(" · ")
  end

  # What discovery already worked out, carried through the form so importing
  # doesn't have to ask the server all over again.
  def carried(model)
    input(type: "hidden", name: "context_windows[#{model.name}]", value: model.context_window) if model.context_window
    input(type: "hidden", name: "dimensions[#{model.name}]", value: model.dimensions) if model.dimensions
    input(type: "hidden", name: "supports_tools[#{model.name}]", value: "1") if model.supports_tools
  end

  # A select where the provider couldn't say, a fixed value where it could.
  def kind_control(model, blocked)
    return if blocked

    if model.kind.nil?
      select(
        name: "kinds[#{model.name}]",
        class: "shrink-0 rounded border border-line bg-void/60 px-2 py-1 text-xs text-fg outline-none " \
               "focus:border-accent transition-colors"
      ) do
        option(value: "chat") { "Chat" }
        option(value: "embedding") { "Embedding" }
      end
    else
      input(type: "hidden", name: "kinds[#{model.name}]", value: model.kind.to_s)
      span(class: "shrink-0 text-xs text-muted") { model.kind.to_s }
    end
  end

  def tag(text)
    span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { text }
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "The server reported no models." }
      p(class: "mt-1 text-xs text-faint") { "For Ollama, that usually means nothing has been pulled yet." }
    end
  end
end
