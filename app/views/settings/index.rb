# frozen_string_literal: true

class Views::Settings::Index < Views::Base
  def initialize(people_count:, server_count:, model_count:, endpoint_count:, prompt:, rounds:, record_api_calls:)
    @people_count = people_count
    @server_count = server_count
    @model_count = model_count
    @endpoint_count = endpoint_count
    @prompt = prompt
    @rounds = rounds
    @record_api_calls = record_api_calls
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Settings" }
      p(class: "mt-1 text-sm text-muted") { "People, inference, endpoints, and general settings." }
    end

    # Cards, not doorways. Every row here leads elsewhere, which makes this a
    # menu page — and a rail on every row is a rail on none. See docs/design.md.
    div(class: "flex flex-col gap-3") do
      entry(
        href: settings_users_path,
        title: "People",
        description: "Who can sign in, and how much of Archyve they see.",
        meta: "#{@people_count} #{'person'.pluralize(@people_count)}"
      ) { people_icon }

      entry(
        href: settings_inference_servers_path,
        title: "Inference",
        description: "Where Archyve sends prompts, and which models it may use.",
        meta: inference_meta
      ) { server_icon }

      entry(
        href: settings_endpoints_path,
        title: "Endpoints",
        description: "Servers documents come from, and the credentials to reach them.",
        meta: endpoint_meta
      ) { endpoint_icon }

      entry(
        href: settings_prompt_path,
        title: "Prompt",
        description: "What every chat's system prompt tells the model.",
        meta: prompt_meta
      ) { prompt_icon }
    end

    preferences
  end

  private

  def page_title = "Settings"

  # Deliberately not cards: everything above leads somewhere, these act here.
  # Hairlines rather than another row of boxes — weight comes from being unlike
  # the cards, not from being a louder one. See docs/design.md.
  def preferences
    section(class: "mt-10") do
      h2(class: "text-xs font-medium uppercase tracking-wider text-faint") { "General settings" }
      div(class: "mt-1 divide-y divide-line") do
        @rounds.each { |key, value| render Views::Settings::Number.new(key:, value:) }
        render Views::Settings::Toggle.new(key: "debug.record_api_calls", on: @record_api_calls)
      end
    end
  end

  def entry(href:, title:, description:, meta:, &icon)
    a(
      href: href,
      class: "flex items-center gap-4 rounded-lg border border-line bg-ink/40 px-5 py-4 hover:border-line-2 transition-colors"
    ) do
      span(class: "grid h-9 w-9 shrink-0 place-items-center rounded bg-accent/10 text-accent", &icon)
      div(class: "min-w-0 flex-1") do
        p(class: "text-sm font-medium text-fg") { title }
        p(class: "mt-0.5 text-xs text-faint") { description }
      end
      span(class: "shrink-0 font-mono tabular-nums text-xs text-muted") { meta }
    end
  end

  # A fresh install has nothing configured, and these should say so rather than
  # read "0 servers" as though that were a quantity.
  def inference_meta
    return "not configured" if @server_count.zero?

    "#{@server_count} #{'server'.pluralize(@server_count)} · #{@model_count} #{'model'.pluralize(@model_count)}"
  end

  def endpoint_meta
    return "none" if @endpoint_count.zero?

    "#{@endpoint_count} #{'endpoint'.pluralize(@endpoint_count)}"
  end

  def prompt_meta
    @prompt.present? ? "set" : "not set"
  end

  def people_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.circle(cx: "9", cy: "8", r: "3.2")
      s.path(d: "M3.5 19a5.5 5.5 0 0 1 11 0")
      s.path(d: "M16 5.6a3.2 3.2 0 0 1 0 4.8M17.5 13.4A5.5 5.5 0 0 1 20.5 19")
    end
  end

  def server_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.rect(x: "3", y: "4", width: "18", height: "7", rx: "1.6")
      s.rect(x: "3", y: "13", width: "18", height: "7", rx: "1.6")
      s.path(d: "M6.5 7.5h.01M6.5 16.5h.01")
    end
  end

  def endpoint_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.path(d: "M9 3v6M15 3v6")
      s.rect(x: "6", y: "9", width: "12", height: "6", rx: "1.6")
      s.path(d: "M12 15v6")
    end
  end

  def prompt_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.path(d: "M12 4v11")
      s.path(d: "M7 10.5 12 15l5-4.5")
      s.path(d: "M5 19.5h14")
    end
  end
end
