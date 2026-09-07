# frozen_string_literal: true

# One source: how it's configured, its scan history, and how to sync or
# delete it. The account of the *latest* scan is Views::Sources::
# LastScan, which lives apart because it updates in place — see the note there.
class Views::Sources::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(source:, syncs:)
    @source = source
    @syncs = syncs
  end

  def view_template
    heading
    configuration

    # Subscribe to the source's stream; SourceSync broadcasts a replace of
    # the LastScan region as a scan starts and finishes. Document progress within
    # a scan comes from that region's own polling — see the note in LastScan.
    turbo_stream_from(@source)
    latest_run

    history if @syncs.many?
    danger_zone
  end

  private

  def page_title = @source.name

  def heading
    header(class: "mb-7 flex items-start justify-between gap-4") do
      div(class: "min-w-0") do
        div(class: "mb-1 text-xs text-faint") do
          a(href: sources_path, class: "hover:text-muted transition-colors") { "Sources" }
        end
        div(class: "flex items-center gap-2") do
          h1(class: "truncate text-2xl font-semibold tracking-tight") { @source.name }
          span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { @source.type_label }
        end
      end
      div(class: "flex shrink-0 items-center gap-2") do
        a(
          href: edit_source_path(@source),
          class: "rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg hover:border-line-2 transition-colors"
        ) { "Edit" }
        sync_button if @source.supports_sync?
      end
    end
  end

  def sync_button
    form(action: sync_source_path(@source), method: "post") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "rounded bg-accent px-3 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Sync now" }
    end
  end

  def configuration
    dl(class: "mb-8 rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      row("Folder", @source.path, mono: true) if @source.respond_to?(:path)
      row("Scan every", interval) if @source.supports_sync?
      row("Last scanned", last_scanned)
      row("File types", Sources::Folder::EXTENSIONS.join(" "), mono: true) if @source.is_a?(Sources::Folder)
      row("Size limit", size_limit) if @source.is_a?(Sources::Folder)
      row("Feeds", fed_collections)
      row("Documents", document_count)
    end
  end

  def row(label, value, mono: false)
    div(class: "flex items-baseline justify-between gap-4 px-5 py-3.5") do
      dt(class: "shrink-0 text-sm text-muted") { label }
      dd(class: "min-w-0 truncate text-sm text-fg #{'font-mono' if mono}") { value }
    end
  end

  def interval
    minutes = (@source.sync_interval_minutes.presence || Sources::Folder::DEFAULT_SYNC_INTERVAL_MINUTES).to_i
    "#{minutes} #{'minute'.pluralize(minutes)}"
  end

  def size_limit
    ActiveSupport::NumberHelper.number_to_human_size(Sources::Folder.max_file_size)
  end

  def fed_collections
    names = @source.collections.order(:name).pluck(:name)
    names.any? ? names.join(", ") : "nothing — documents land in Unsorted"
  end

  def last_scanned
    return "not applicable" unless @source.supports_sync?
    return "never" if @source.last_synced_at.nil?

    "#{time_ago_in_words(@source.last_synced_at)} ago"
  end

  def document_count
    live = @source.documents.where.not(status: "removed").count
    removed = @source.documents.where(status: "removed").count
    removed.zero? ? live.to_s : "#{live} (#{removed} removed)"
  end

  # The live region. Only sources that scan have one — "Last scan" on manual
  # upload would be a permanently empty box.
  def latest_run
    return unless @source.supports_sync?

    section(class: "mb-8") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Last scan" }
      render Views::Sources::LastScan.new(source: @source)
    end
  end

  def history
    section(class: "mb-8") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Earlier scans" }
      div(class: "overflow-x-auto rounded-lg border border-line bg-ink/40") do
        table(class: "w-full text-sm") do
          thead(class: "border-b border-line text-xs text-faint") do
            tr do
              th(class: "px-4 py-2 text-left font-normal") { "When" }
              th(class: "px-4 py-2 text-left font-normal") { "Result" }
              th(class: "px-4 py-2 text-right font-normal") { "Created" }
              th(class: "px-4 py-2 text-right font-normal") { "Updated" }
              th(class: "px-4 py-2 text-right font-normal") { "Removed" }
            end
          end
          tbody(class: "divide-y divide-line") do
            @syncs.drop(1).each { |sync| history_row(sync) }
          end
        end
      end
    end
  end

  def history_row(sync)
    tr do
      td(class: "whitespace-nowrap px-4 py-2 text-muted") { "#{time_ago_in_words(sync.started_at)} ago" }
      td(class: "px-4 py-2 text-muted") { sync.status }
      td(class: "px-4 py-2 text-right font-mono tabular-nums text-muted") { sync.created_count.to_s }
      td(class: "px-4 py-2 text-right font-mono tabular-nums text-muted") { sync.updated_count.to_s }
      td(class: "px-4 py-2 text-right font-mono tabular-nums text-muted") { sync.removed_count.to_s }
    end
  end

  def danger_zone
    div(class: "rounded-lg border border-line px-5 py-4") do
      div(class: "flex items-center justify-between gap-4") do
        div do
          p(class: "text-sm text-fg") { "Delete this source" }
          p(class: "mt-0.5 text-xs text-faint") { "Its documents, and everything indexed from them, go with it — they belong to the source." }
        end
        form(action: source_path(@source), method: "post") do
          input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
          input(type: "hidden", name: "_method", value: "delete")
          button(
            type: "submit",
            class: "shrink-0 rounded border border-red-400/40 px-3 py-2 text-sm text-red-300 hover:bg-red-400/10 transition-colors",
            data: { turbo_confirm: "Delete “#{@source.name}” and all #{@source.documents.count} of its documents?" }
          ) { "Delete" }
        end
      end
    end
  end
end
