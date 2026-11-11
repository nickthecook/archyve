# frozen_string_literal: true

# One server: whether Archyve can reach it, and what it may use it for.
class Views::Settings::InferenceServers::Show < Views::Base
  def initialize(server:, embedded_chunk_count:, active_embedding:, corpus_model:, default_chat:)
    @server = server
    @embedded_chunk_count = embedded_chunk_count
    @active_embedding = active_embedding
    @corpus_model = corpus_model
    # Resolved once by the controller rather than asked per row: the default is
    # a Setting lookup now, not a column on the loaded model.
    @default_chat = default_chat
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Inference", settings_inference_servers_path], @server.name)
    heading
    check_panel
    chat_models
    embedding_model
  end

  private

  def page_title = @server.name

  def heading
    header(class: "mb-7 flex items-start justify-between gap-4") do
      div(class: "min-w-0") do
        div(class: "flex items-center gap-2") do
          h1(class: "text-2xl font-semibold tracking-tight") { @server.name }
          tag(@server.type_label)
          tag("provisioned") if @server.provisioned?
          tag("disabled") unless @server.enabled?
        end
        p(class: "mt-1 truncate font-mono text-sm text-muted") { @server.base_url.presence || "api.openai.com" }
        provisioning_note if @server.provisioned?
      end
      div(class: "flex shrink-0 items-center gap-2") do
        check_button
        a(href: edit_settings_inference_server_path(@server), class: button_class(:quiet)) { "Edit" } unless @server.provisioned?
        remove_button
      end
    end
  end

  def provisioning_note
    p(class: "mt-1 text-xs text-faint") do
      if @server.enabled?
        "Provisioned from #{Inference::Spec::VAR}, so it's changed there rather than here."
      else
        "No longer in #{Inference::Spec::VAR}. Its models can't be chosen for new chats; remove it once nothing needs it."
      end
    end
  end

  # Outlined, not solid: checking verifies, it doesn't commit anything. See the
  # accent ladder in docs/design.md.
  def check_button
    form(action: check_settings_inference_server_path(@server), method: "post", class: "inline") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: button_class(:outlined)) { "Check" }
    end
  end

  # Last in the row, furthest from Check — and what it costs is said in the
  # confirmation rather than beside the button, because that is the moment
  # somebody is deciding. Same danger weight as removing an endpoint.
  def remove_button
    return blocked_remove_button if @server.removal_refusal

    form(
      action: settings_inference_server_path(@server),
      method: "post",
      class: "inline",
      data: { turbo_confirm: remove_confirmation }
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(type: "submit", class: button_class(:danger)) { "Remove" }
    end
  end

  def remove_confirmation
    "Remove “#{@server.name}” and its models? Documents already embedded keep their vectors."
  end

  # Disabled rather than hidden, the same way an endpoint with sources still
  # shows its button: a control that vanishes leaves somebody looking for it.
  # The reason is spelled out in the embedding panel below, which is where the
  # archive's dependency on this server is already explained.
  def blocked_remove_button
    span(class: button_class(:danger, "opacity-40"), aria_disabled: "true", title: @server.removal_refusal) { "Remove" }
  end

  def check_panel
    div(class: "mb-8 rounded-lg border border-line bg-ink/40 px-5 py-4") do
      if !@server.checked?
        p(class: "text-sm text-muted") { "Not checked yet." }
        p(class: "mt-1 text-xs text-faint") { "Check to confirm Archyve can reach this server before relying on it." }
      elsif @server.reachable?
        p(class: "text-sm text-fg") { "Answered #{time_ago_in_words(@server.last_checked_at)} ago." }
        p(class: "mt-1 text-xs text-faint") { @server.lists_models? ? "Fetch models to see what it can run." : "Add a deployment by name to use it." }
      else
        p(class: "text-sm text-red-300") { "Unreachable as of #{time_ago_in_words(@server.last_checked_at)} ago." }
        p(class: "mt-1 break-words font-mono text-xs text-red-300/70") { @server.last_check_error.to_s }
      end
    end
  end

  def discover_label = @server.lists_models? ? "Fetch models" : "Add deployment"

  def chat_models
    section(class: "mb-8") do
      div(class: "mb-3 flex flex-wrap items-center justify-between gap-3") do
        h2(class: "text-sm font-medium text-fg") { "Chat models" }
        unless @server.provisioned?
          div(class: "flex items-center gap-2") do
            a(href: discover_settings_inference_server_path(@server), class: button_class(:outlined)) { discover_label }
            a(href: new_settings_inference_server_model_path(@server), class: button_class(:quiet)) { "Add manually" }
          end
        end
      end

      models = @server.inference_models.select(&:chat?).sort_by(&:name)
      models.any? ? model_list(models) : no_chat_models
    end
  end

  def model_list(models)
    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      models.each { |model| model_row(model) }
    end
  end

  # Narrow: the actions drop below the name rather than squeezing it — a model
  # name plus two badges already fills a phone's width on its own.
  def model_row(model)
    li(class: "flex flex-col gap-2 px-5 py-4 sm:flex-row sm:items-center sm:justify-between sm:gap-3") do
      div(class: "min-w-0") do
        div(class: "flex items-center gap-2") do
          # min-w-0 or truncate never fires: a flex item won't shrink below its
          # content width, and a registry name like hf.co/…-GGUF:Q4_K_M is long
          # enough to push the page sideways on a phone.
          span(class: "min-w-0 truncate font-mono text-sm text-fg") { model.name }
          tag("default") if model.id == @default_chat&.id
          tag("tools") if model.supports_tools?
          tag("responses") if model.chat? && model.responses?
          tag("disabled") unless model.enabled?
        end
        p(class: "mt-0.5 text-xs text-faint") { model_detail(model) }
      end
      model_actions(model)
    end
  end

  def model_actions(model)
    div(class: "flex shrink-0 items-center gap-4") do
      unless @server.provisioned?
        a(
          href: edit_settings_inference_server_model_path(@server, model),
          class: "text-xs text-faint hover:text-fg transition-colors"
        ) { "Edit" }
      end
      remove(model) if model.removal_refusal.nil?
    end
  end

  def model_detail(model)
    parts = []
    parts << model.display_name if model.display_name.present?
    parts << "#{delimited(model.context_window)} token context" if model.context_window
    parts << "can't call tools — retrieval won't work in chat" unless model.supports_tools?
    parts.join(" · ")
  end

  def tag(text)
    span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { text }
  end

  def no_chat_models
    div(class: "rounded-lg border border-dashed border-line px-4 py-10 text-center") do
      p(class: "text-sm text-muted") { "No chat models from this server." }
      p(class: "mt-1 text-xs text-faint") { "Fetch models to see what it has." }
    end
  end

  # The embedding model gets the dashed-quiet costume the app uses for things
  # that aren't quite ordinary records — it is one per archive, not one of many,
  # and mostly it cannot be changed at all.
  def embedding_model
    model = @server.inference_models.find(&:embedding?)

    section(class: "mb-8") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Embedding model" }

      if model
        embedding_panel(model)
      elsif @active_embedding
        embedding_elsewhere
      else
        no_embedding_model
      end
    end
  end

  def embedding_panel(model)
    div(class: "rounded-lg border border-dashed border-line px-5 py-4") do
      div(class: "flex items-center justify-between gap-3") do
        span(class: "font-mono text-sm text-fg") { model.name }
        span(class: "font-mono tabular-nums text-xs text-muted") { "#{model.dimensions} dimensions" }
      end
      p(class: "mt-2 text-xs text-faint") { embedding_note }
      div(class: "mt-3") { remove(model) } if model.removal_refusal.nil?
    end
  end

  def embedding_note
    if frozen_corpus?
      "#{delimited(@embedded_chunk_count)} chunks are embedded with this model. Vectors from " \
        "different models aren't comparable, so changing it means re-embedding the whole archive — which " \
        "Archyve can't do yet."
    else
      "Nothing is embedded yet, so this can still be changed. Once documents are processed it's fixed."
    end
  end

  # An archive has one embedding model, so another server holding it is the
  # ordinary case — and this page claiming search can't run would be a lie
  # about a perfectly healthy archive.
  def embedding_elsewhere
    div(class: "rounded-lg border border-dashed border-line px-4 py-10 text-center") do
      p(class: "text-sm text-muted") do
        "#{@active_embedding.name} on #{@active_embedding.inference_server.name}."
      end
      p(class: "mt-1 text-xs text-faint") { "Your embedding model is in another castle." }
    end
  end

  # Names what the corpus was embedded with, because that string is the only
  # way back: a replacement model has to claim it exactly, and nothing else on
  # any page would say what it was.
  def no_embedding_model
    div(class: "rounded-lg border border-dashed border-line px-4 py-10 text-center") do
      p(class: "text-sm text-muted") { "No embedding model." }
      p(class: "mt-1 text-xs text-faint") { orphaned_corpus_note } if @corpus_model
      p(class: "mt-1 text-xs text-faint") do
        "Documents can't be processed and search can't run until one is configured."
      end
    end
  end

  def orphaned_corpus_note
    "#{delimited(@embedded_chunk_count)} #{'chunk'.pluralize(@embedded_chunk_count)} " \
      "#{@embedded_chunk_count == 1 ? 'is' : 'are'} embedded with #{@corpus_model} — add that model back to " \
      "search them again."
  end

  def frozen_corpus? = @embedded_chunk_count.positive?

  # No phlex-rails adapter for this one is registered on Components::Base, and
  # registering it app-wide for a single call site would be the tail wagging the
  # dog. Sources::Folder reaches for ActiveSupport::NumberHelper the same way.
  def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)

  # inline-flex, not inline: a block form wrapping an inline-block button is a
  # line box, 8px taller than the button, so centring it in the actions row put
  # "Remove" 2px below "Edit".
  def remove(model)
    form(action: settings_inference_server_model_path(@server, model), method: "post", class: "inline-flex") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "shrink-0 text-xs text-faint hover:text-red-300 transition-colors"
      ) { "Remove" }
    end
  end
end
