# frozen_string_literal: true

# What the server says it can run, ticked into Archyve.
#
# What discovery reports is taken as fact here. For Ollama it is: /api/show
# declares each model's capabilities. For OpenAI it is RubyLLM pattern-matching
# the model id, which is a good guess rather than a report — an earlier version
# said so on every row, and the hedging cost more in confusion than it bought in
# accuracy. Anything discovery gets wrong is fixable on the model's own form.
#
# A chat model the provider says can't call tools is shown but not importable:
# Archyve gives the model retrieval as a tool, so one that can't call tools can
# hold a conversation without ever reaching the archive, which is the only
# reason to add it. Embedding models are exempt — they never call anything.
#
# A provider that didn't say is not refused: the row says tool support is
# unknown and the tick answers it. Blocking on nil made every model on a vLLM
# or LM Studio host unimportable, since RubyLLM has an id pattern for OpenAI's
# own catalogue and nothing else.
class Views::Settings::InferenceServers::Discover < Views::Base
  def initialize(server:, discovered:, existing:, embedding_locked:, has_embedding_model:)
    @server = server
    @discovered = discovered
    @existing = existing
    @embedding_locked = embedding_locked
    @has_embedding_model = has_embedding_model
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Inference", settings_inference_servers_path],
      [@server.name, settings_inference_server_path(@server)],
      "Models"
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Models on #{@server.name}" }
      p(class: "mt-1 text-sm text-muted") { subtitle }
    end

    @discovered.any? ? picker : empty_state
  end

  private

  def page_title = "Models on #{@server.name}"

  def subtitle
    importable = rows.count { |_model, blocked| blocked.nil? }
    skipped = rows.size - importable
    sentence = "#{@discovered.size} #{'model'.pluralize(@discovered.size)} reported, #{importable} importable."
    skipped.positive? ? "#{sentence} Tick the ones Archyve may use; the rest are listed below with why." : "#{sentence} Tick the ones Archyve may use."
  end

  # Three bands, most useful first. Each row's reason is worked out once here so
  # the ordering and the row itself agree.
  def rows
    @rows ||= @discovered
      .map { |model| [model, blocked_reason(model, @existing.include?(model.name))] }
      .sort_by { |model, blocked| [band(model, blocked), model.name] }
  end

  # Importable first. With a hundred-odd models on a real OpenAI account the top
  # of the list should be the handful someone actually came for; everything
  # Archyve can't take sits below with its reason.
  def band(_model, blocked) = blocked ? 1 : 0

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
        rows.each { |model, blocked| row(model, blocked) }
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

  def row(model, blocked)
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
          tag("#{model.dimensions}d") if model.dimensions
        end
        note = blocked || detail(model).presence
        p(class: "mt-0.5 text-xs text-faint") { note } if note
        tools_note if model.supports_tools.nil? && blocked.nil?
        carried(model)
      end
      kind_control(model) unless blocked
    end
  end

  # Where tool support wasn't reported, ticking the row is the answer: the
  # model imports as tool-capable because a person said to import it. Said out
  # loud beforehand rather than collected in a second checkbox, which made the
  # tick mean nothing on its own and turned a wrong answer into an error after
  # the fact.
  def tools_note
    p(class: "mt-0.5 text-xs text-faint") { "Tool support unknown — tick only if it can call tools." }
  end

  # Why a row can't be ticked, or nil. Said out loud on the row rather than
  # leaving a checkbox that silently does nothing — or, worse, leaving a speech
  # model tickable so it files itself as a chat model and breaks the first time
  # anything asks it to hold a conversation.
  def blocked_reason(model, already)
    return "Already imported." if already
    return model.skip_reason if model.skipped?
    return embedding_blocked_reason if model.kind.to_s == "embedding"

    # Everything else is treated as a chat model, and a chat model earns its
    # place here by being able to call tools. **Embedding models are exempt** —
    # they are asked to turn text into a vector and never call anything, so
    # requiring tool support of them would block the one model the archive
    # cannot work without.
    "Can't call tools, so it couldn't draw on the archive in chat." if model.supports_tools == false
  end

  def embedding_blocked_reason
    return "Archyve already has an embedding model." if @has_embedding_model
    return unless @embedding_locked

    "The archive is already embedded — changing the embedding model needs a re-embed, which Archyve can't do yet."
  end

  # Deliberately says nothing when the provider couldn't classify the model.
  # The row already shows that: it sits below the tool-capable ones with an
  # unticked box and a kind picker beside it. Spelling it out as well put a
  # sentence of hedging on most rows of a hundred-model list, which read as a
  # problem rather than as the ordinary state of an API that reports ids.
  def detail(model)
    parts = []
    parts << "#{ActiveSupport::NumberHelper.number_to_delimited(model.context_window)} token context" if model.context_window
    parts << "reported as an embedding model" if model.kind.to_s == "embedding"
    parts.join(" · ")
  end

  # What discovery already worked out, carried through the form so importing
  # doesn't have to ask the server all over again.
  #
  # Tool support rides along for a model discovery didn't report on, because
  # importing one is the person saying it calls tools — see #tools_note. Only
  # a reported `false` withholds it, and that row can't be ticked anyway.
  def carried(model)
    input(type: "hidden", name: "context_windows[#{model.name}]", value: model.context_window) if model.context_window
    input(type: "hidden", name: "dimensions[#{model.name}]", value: model.dimensions) if model.dimensions
    input(type: "hidden", name: "supports_tools[#{model.name}]", value: "1") unless model.supports_tools == false
  end

  # A select where the provider couldn't say, a fixed value where it could.
  def kind_control(model)
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
