# frozen_string_literal: true

# One source: how it's configured, its scan history, and how to sync or
# delete it. The account of the *latest* scan is Views::Sources::
# LastScan, which lives apart because it updates in place — see the note there.
class Views::Sources::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Phlex::Rails::Helpers::TurboFrameTag

  DOCUMENTS_FRAME = "source_documents_frame"

  def initialize(source:, syncs:, documents:, filter: "", back: nil)
    @source = source
    @syncs = syncs
    @documents = documents
    @filter = filter
    @back = back
  end

  def view_template
    middle = @back ? [@back.label, @back.href] : ["Sources", sources_path]
    breadcrumb(["Collections", collections_path], middle, @source.name)

    heading
    configuration

    # Subscribe to the source's stream; SourceSync broadcasts a replace of
    # the LastScan region as a scan starts and finishes. Document progress within
    # a scan comes from that region's own polling — see the note in LastScan.
    turbo_stream_from(@source)
    latest_run

    history if @syncs.many?
    documents
    render Views::Sources::Reprocess.new(source: @source)
    danger_zone if may_on?(@source, :manager)
  end

  private

  def page_title = @source.name

  def heading
    header(class: "mb-7 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div(class: "min-w-0") do
        div(class: "flex items-center gap-2") do
          h1(class: "truncate text-2xl font-semibold tracking-tight") { @source.name }
          span(class: "shrink-0 rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { @source.type_label }
        end
      end
      div(class: "flex shrink-0 items-center gap-2") do
        people_link if may?(:admin)
        a(
          href: edit_source_path(@source),
          class: button_class(:quiet)
        ) { "Edit" }
        sync_button if @source.supports_sync?
      end
    end
  end

  def people_link
    a(
      href: source_people_path(@source),
      class: button_class(:quiet)
    ) { "People" }
  end

  def sync_button
    form(action: sync_source_path(@source), method: "post") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: button_class(:solid)
      ) { "Sync now" }
    end
  end

  def configuration
    dl(class: "mb-8 rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      row("Server", @source.endpoint.name) if @source.endpoint
      row("Folder", @source.path, mono: true) if @source.is_a?(Sources::Folder)
      row("Syncs", selector_summary) if @source.is_a?(Sources::Bookstack)
      row("Folders", @source.selected_folders.join("  "), mono: true) if @source.is_a?(Sources::Nextcloud)
      row("Scan every", interval) if @source.supports_sync?
      row("OCR", @source.ocr? ? "on" : "off") if @source.supports_ocr?
      row("Last scanned", last_scanned)
      row("File types", Source::EXTRACTABLE_EXTENSIONS.join(" "), mono: true) if @source.filters_extensions?
      row("Size limit", size_limit) if @source.filters_extensions?
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
    minutes = (@source.sync_interval_minutes.presence || Source::DEFAULT_SYNC_INTERVAL_MINUTES).to_i
    "#{minutes} #{'minute'.pluralize(minutes)}"
  end

  def size_limit
    ActiveSupport::NumberHelper.number_to_human_size(Source.max_file_size)
  end

  # Counted by kind rather than named: the names live on the wiki, and a page
  # that costs three API calls to draw is not one this page should be making.
  # The edit form lists them by name — it is already talking to the server.
  def selector_summary
    counts = @source.selections.group_by(&:first).transform_values(&:size)
    return "nothing" if counts.empty?

    counts.map { |kind, count| "#{count} #{kind.pluralize(count)}" }.join(", ")
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

  # Failed first, because they are why someone opens a source. A frame so that
  # filtering and paging don't throw the reader back to the top of the page;
  # `_top` keeps the document links themselves as full navigations.
  def documents
    section(class: "mb-8") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Documents" }
      turbo_frame_tag(DOCUMENTS_FRAME, target: "_top", data: { turbo_action: "advance" }) do
        document_filter
        div(id: "source_documents", data: progress_data(terminal: @documents.records.all?(&:settled?))) do
          @documents.any? ? document_list : no_documents
        end
        render Views::Pager.new(
          page: @documents, action: source_path(@source), params: { q: @filter }.compact_blank, frame: DOCUMENTS_FRAME
        )
      end
    end
  end

  def document_filter
    form(action: source_path(@source), method: "get", class: "mb-3", data: { turbo_frame: DOCUMENTS_FRAME }) do
      input(
        type: "search", name: "q", value: @filter, placeholder: "Filter by title", autocomplete: "off",
        class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
      )
    end
  end

  def document_list
    ul(class: "divide-y divide-line rounded-lg border border-line bg-ink/40") do
      @documents.records.each do |document|
        render Views::Documents::Row.new(document:, purgeable: document.purgeable?, show_source: false)
      end
    end
  end

  def no_documents
    div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
      p(class: "text-sm text-muted") { @filter.present? ? "No documents match “#{@filter}”." : "No documents yet." }
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
            class: button_class(:danger, "shrink-0"),
            data: { turbo_confirm: "Delete “#{@source.name}” and all #{@source.documents.count} of its documents?" }
          ) { "Delete" }
        end
      end
    end
  end
end
