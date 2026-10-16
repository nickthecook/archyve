# frozen_string_literal: true

# Every configured inference server, and whether Archyve can reach it.
class Views::Settings::InferenceServers::Index < Views::Base
  def initialize(servers:, chat_models:, default_model_id:)
    @servers = servers
    @chat_models = chat_models
    @default_model_id = default_model_id
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Inference")

    header(class: "mb-10") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Inference" }
      p(class: "mt-1 text-sm text-muted") { "Where Archyve sends prompts, and which models it may use." }
    end

    render Views::Settings::DefaultModel.new(models: @chat_models, selected_id: @default_model_id)

    servers_section
  end

  private

  def page_title = "Inference"

  # The servers are one part of this page now rather than the whole of it, so
  # they get a heading, and "Add server" belongs to it rather than to the page.
  def servers_section
    section do
      div(class: "mb-3 flex flex-wrap items-center justify-between gap-x-4 gap-y-2") do
        h2(class: "text-xs font-medium uppercase tracking-wider text-faint") { "Inference servers" }
        a(
          href: new_settings_inference_server_path,
          class: button_class(:solid, "shrink-0 py-1")
        ) { "Add server" }
      end
      @servers.any? ? list : empty_state
    end
  end

  def list
    div(class: "flex flex-col gap-3") do
      @servers.each { |server| card(server) }
    end
  end

  def card(server)
    a(
      href: settings_inference_server_path(server),
      class: "block rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors"
    ) do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          div(class: "flex items-center gap-2") do
            span(class: "truncate text-sm font-medium text-fg") { server.name }
            span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") do
              server.type_label
            end
          end
          p(class: "mt-1 truncate font-mono text-xs text-faint") { server.base_url.presence || "api.openai.com" }
        end
        check_state(server)
      end
      div(class: "mt-3 flex items-center gap-4 text-xs text-muted") do
        span(class: "font-mono tabular-nums") { model_summary(server) }
      end
    end
  end

  def model_summary(server)
    models = server.inference_models
    chat = models.count(&:chat?)
    embedding = models.count(&:embedding?)
    parts = ["#{chat} chat"]
    parts << "#{embedding} embedding" if embedding.positive?
    parts.join(" · ")
  end

  # Grey for never-checked rather than a red light: not having pressed the
  # button isn't a fault.
  def check_state(server)
    return span(class: "shrink-0 text-xs text-faint") { "not checked" } unless server.checked?

    span(class: "shrink-0 inline-flex items-center gap-1.5 text-xs text-muted") do
      span(class: "h-1.5 w-1.5 rounded-full #{server.reachable? ? 'bg-emerald-400' : 'bg-red-400'}")
      plain(server.reachable? ? "reachable" : "unreachable")
    end
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No inference servers yet." }
      p(class: "mt-1 text-xs text-faint") { "Until one is added, Archyve can't embed documents or answer in chat." }
    end
  end
end
