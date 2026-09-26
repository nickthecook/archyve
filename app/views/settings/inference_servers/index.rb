# frozen_string_literal: true

# Every configured inference server, and whether Archyve can reach it.
class Views::Settings::InferenceServers::Index < Views::Base
  def initialize(servers:)
    @servers = servers
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Inference")

    header(class: "mb-7 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div do
        h1(class: "text-2xl font-semibold tracking-tight") { "Inference" }
        p(class: "mt-1 text-sm text-muted") { "Where Archyve sends prompts, and which models it may use." }
      end
      a(
        href: new_settings_inference_server_path,
        class: "shrink-0 rounded bg-accent px-3 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Add server" }
    end

    @servers.any? ? list : empty_state
  end

  private

  def page_title = "Inference"

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
