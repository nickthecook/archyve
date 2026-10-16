# frozen_string_literal: true

# Every configured source, and the state of each one's last scan. Manual upload
# appears here too — it produces documents like any other source, it just has
# nothing to poll.
class Views::Sources::Index < Views::Base
  LIVE_REGION = "sources_list".freeze

  def initialize(sources:)
    @sources = sources
  end

  def view_template
    # Collections, not Settings: sources live with the content they produce, and
    # the only way in is the doorway on the collections index.
    breadcrumb(["Collections", collections_path], "Sources")

    heading
    @sources.any? ? list : empty_state
  end

  private

  def page_title = "Sources"

  def heading
    header(class: "mb-7 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div do
        h1(class: "text-2xl font-semibold tracking-tight") { "Sources" }
        p(class: "mt-1 text-sm text-muted") { "Where the archive's documents come from, and when each source was last scanned." }
      end
      a(
        href: new_source_path,
        class: button_class(:solid, "shrink-0")
      ) { "Add source" }
    end
  end

  # The whole list is the live region: the statuses on these cards move while
  # work runs elsewhere, and nothing broadcasts to an index — per-source
  # broadcasts would be a message apiece to redraw one badge.
  def list
    div(id: LIVE_REGION, data: progress_data(terminal: !watching?), class: "flex flex-col gap-3") do
      @sources.each { |source| card(source) }
    end
  end

  # Poll only while something here can still change on its own. A list of
  # settled sources is a static page, and polling it for every visitor would be
  # a request every couple of seconds to redraw the same thing.
  def watching? = reprocessing.any? || scanning.any?

  # Mid-scan, either holding a job or stopped on its budget — both are states a
  # source moves off without anyone asking.
  def scanning
    @scanning ||= SourceSync.where(source: @sources)
      .where.not(status: SourceSync::TERMINAL_STATUSES)
      .pluck(:source_id).to_set
  end

  def card(source)
    a(
      href: source_path(source),
      class: "block rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors"
    ) do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          div(class: "flex items-center gap-2") do
            span(class: "truncate text-sm font-medium text-fg") { source.name }
            span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { source.type_label }
          end
          p(class: "mt-1 truncate font-mono text-xs text-faint") { source.location } if source.location.present?
        end
        state(source)
      end
      div(class: "mt-3 flex items-center gap-4 text-xs text-muted") do
        span(class: "font-mono tabular-nums") { document_count(source) }
        span(class: "text-faint") { last_scan(source) }
      end
    end
  end

  def document_count(source)
    count = source.documents.where.not(status: "removed").count
    "#{count} #{'document'.pluralize(count)}"
  end

  def last_scan(source)
    return "not scanned — documents arrive by upload" unless source.supports_sync?
    return "never scanned" if source.last_synced_at.nil?

    "scanned #{time_ago_in_words(source.last_synced_at)} ago"
  end

  # What the source is doing now, or failing that what its last scan did. A
  # reprocess wins because it is happening, where a sync status is a thing that
  # already happened — and it is the only state a manual-upload source has,
  # since those never scan.
  def state(source)
    return reprocess_state if reprocessing.include?(source.id)

    sync_state(source)
  end

  # One query for the page rather than one per card: this list is already a
  # column of per-source counts, and another round trip apiece is not the way
  # to add to it.
  def reprocessing
    @reprocessing ||= SourceReprocess.running.where(source: @sources).pluck(:source_id).to_set
  end

  def reprocess_state
    span(class: "shrink-0 inline-flex items-center gap-1.5 text-xs text-muted") do
      span(class: "h-1.5 w-1.5 rounded-full bg-accent")
      plain "reprocessing"
    end
  end

  # A dot for the last run's outcome. Absent for sources that never scan,
  # rather than a permanently grey light suggesting something is wrong.
  def sync_state(source)
    return unless source.supports_sync?

    sync = source.latest_sync
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
      p(class: "text-sm text-muted") { "No sources yet." }
      p(class: "mt-1 text-xs text-faint") { "Add one to start syncing documents from a source." }
    end
  end
end
