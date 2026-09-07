# frozen_string_literal: true

# Every configured source, and the state of each one's last scan. Manual upload
# appears here too — it produces documents like any other connector, it just has
# nothing to poll.
class Views::Settings::Connectors::Index < Views::Base
  def initialize(connectors:)
    @connectors = connectors
  end

  def view_template
    heading
    @connectors.any? ? list : empty_state
  end

  private

  def page_title = "Connectors"

  def heading
    header(class: "mb-7 flex items-start justify-between gap-4") do
      div do
        div(class: "mb-1 text-xs text-faint") do
          a(href: settings_path, class: "hover:text-muted transition-colors") { "Settings" }
        end
        h1(class: "text-2xl font-semibold tracking-tight") { "Connectors" }
        p(class: "mt-1 text-sm text-muted") { "Where the archive's documents come from, and when each source was last scanned." }
      end
      a(
        href: new_settings_connector_path,
        class: "shrink-0 rounded bg-accent px-3 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Add connector" }
    end
  end

  def list
    div(class: "flex flex-col gap-3") do
      @connectors.each { |connector| card(connector) }
    end
  end

  def card(connector)
    a(
      href: settings_connector_path(connector),
      class: "block rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors"
    ) do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          div(class: "flex items-center gap-2") do
            span(class: "truncate text-sm font-medium text-fg") { connector.name }
            span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { connector.type_label }
          end
          p(class: "mt-1 truncate font-mono text-xs text-faint") { subtitle(connector) }
        end
        sync_state(connector)
      end
      div(class: "mt-3 flex items-center gap-4 text-xs text-muted") do
        span(class: "font-mono tabular-nums") { document_count(connector) }
        span(class: "text-faint") { last_scan(connector) }
      end
    end
  end

  def subtitle(connector)
    connector.try(:path) || "Documents uploaded by hand"
  end

  def document_count(connector)
    count = connector.documents.where.not(status: "removed").count
    "#{count} #{'document'.pluralize(count)}"
  end

  def last_scan(connector)
    return "not scanned — documents arrive by upload" unless connector.supports_sync?
    return "never scanned" if connector.last_synced_at.nil?

    "scanned #{time_ago_in_words(connector.last_synced_at)} ago"
  end

  # A dot for the last run's outcome. Absent for connectors that never scan,
  # rather than a permanently grey light suggesting something is wrong.
  def sync_state(connector)
    return unless connector.supports_sync?

    sync = connector.latest_sync
    return span(class: "shrink-0 text-xs text-faint") { "never run" } if sync.nil?

    span(class: "shrink-0 inline-flex items-center gap-1.5 text-xs text-muted") do
      span(class: "h-1.5 w-1.5 rounded-full #{dot(sync)}")
      plain sync.status
    end
  end

  def dot(sync)
    case sync.status
    when "completed" then "bg-emerald-400"
    when "failed" then "bg-red-400"
    else "bg-accent"
    end
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No connectors yet." }
      p(class: "mt-1 text-xs text-faint") { "Add one to start syncing documents from a source." }
    end
  end
end
