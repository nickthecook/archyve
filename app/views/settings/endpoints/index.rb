# frozen_string_literal: true

class Views::Settings::Endpoints::Index < Views::Base
  def initialize(endpoints:)
    @endpoints = endpoints
  end

  def view_template
    a(href: settings_path, class: "text-sm text-muted hover:text-fg transition-colors") { "← Settings" }

    header(class: "mt-3 mb-7 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div do
        h1(class: "text-2xl font-semibold tracking-tight") { "Endpoints" }
        p(class: "mt-1 text-sm text-muted") { "Servers documents come from, and the credentials to reach them." }
      end
      a(
        href: new_settings_endpoint_path,
        class: "shrink-0 rounded bg-accent px-3 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Add endpoint" }
    end

    @endpoints.any? ? list : empty_state
  end

  private

  def page_title = "Endpoints"

  def list
    div(class: "flex flex-col gap-3") do
      @endpoints.each { |endpoint| card(endpoint) }
    end
  end

  def card(endpoint)
    a(
      href: settings_endpoint_path(endpoint),
      class: "block rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors"
    ) do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          div(class: "flex items-center gap-2") do
            span(class: "truncate text-sm font-medium text-fg") { endpoint.name }
            span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") do
              endpoint.type_label
            end
          end
          p(class: "mt-1 truncate font-mono text-xs text-faint") { endpoint.base_url }
        end
        render Views::Settings::Endpoints::AccessState.new(endpoint:)
      end
      div(class: "mt-3 font-mono tabular-nums text-xs text-muted") { source_summary(endpoint) }
    end
  end

  def source_summary(endpoint)
    count = endpoint.sources.size
    "#{count} #{'source'.pluralize(count)}"
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No endpoints yet." }
      p(class: "mt-1 text-xs text-faint") do
        "Until one is added, operators can't create sources that pull from a remote system like a wiki."
      end
    end
  end
end
