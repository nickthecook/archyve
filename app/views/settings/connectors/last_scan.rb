# frozen_string_literal: true

# The live region of a connector's page: what the last scan did, and how far the
# documents it produced have got.
#
# Kept helper-free — dom id computed directly, no route or Phlex view helpers —
# so ConnectorSync can render it to a string and broadcast it over Turbo Streams,
# the same arrangement Views::Documents::Detail has with Document. That is why
# ActionView::Helpers::DateHelper is included outright rather than using the
# phlex-rails adapter: the adapter reaches for a view context, which doesn't
# exist when a model renders this from a job.
class Views::Settings::Connectors::LastScan < Components::Base
  include ActionView::Helpers::DateHelper

  METER = {
    "processed" => "bg-emerald-400",
    "processing" => "bg-accent",
    "pending" => "bg-line-2",
    "failed" => "bg-red-400"
  }.freeze

  HINTS = {
    "found" => "Items the scan saw in the source, before deciding what to do with each one.",
    "created" => "New to the archive. A document was created and queued for processing.",
    "updated" => "Already in the archive, but the source version moved, so it is being ingested again.",
    "unchanged" => "Already in the archive and still matching the source. Nothing to do — this is the " \
                   "cheap path that keeps re-scanning a large source inexpensive.",
    "removed" => "Gone from the source, so the document was removed from the archive along with everything " \
                 "indexed from it. Collection memberships you made by hand are kept.",
    "skipped" => "Present in the source but not ingestable — currently, over the size limit. " \
                 "Nothing was added to the archive, and nothing was deleted.",
    "stale" => "In the archive, but the source has since changed into something that can't be ingested. " \
               "These documents are out of date and will not catch up on their own.",
    "errored" => "The scan hit an error on these items and left them alone — nothing was removed — so the " \
                 "next scan tries again. Failures reading or extracting a file happen later, and appear " \
                 "as failed documents below."
  }.freeze

  # Keyed on the connector, not the run: a new scan replaces this region with a
  # different run, so the target has to outlive any one of them.
  def self.dom_id(connector)
    "#{ActionView::RecordIdentifier.dom_id(connector)}_last_scan"
  end

  def initialize(connector:)
    @connector = connector
    @sync = connector.latest_sync
  end

  def view_template
    # The wrapper always renders, even with no scan yet, so the broadcast target
    # exists before the first run does.
    #
    # `progress` polls while anything is still moving. It is the primary
    # mechanism here rather than a safety net: per-document broadcasts would mean
    # one re-render of this whole panel per status change per document — three
    # thousand for a thousand-file scan — to move an aggregate that nobody needs
    # updated more than every couple of seconds. ConnectorSync still broadcasts,
    # so starting and finishing a scan land instantly.
    div(
      id: self.class.dom_id(@connector),
      # .to_s: Phlex renders a bare `true` as a valueless attribute and omits
      # `false`, which Stimulus boolean values can't read — they need "true"/"false".
      data: { controller: "progress", progress_terminal_value: settled?.to_s }
    ) do
      @sync.nil? ? empty_state : panel
    end
  end

  private

  # Nothing left to watch: the scan is over and every document it produced has
  # reached a terminal state. A stalled run counts as settled — it isn't going to
  # move on its own, and polling forever would be pretending otherwise.
  def settled?
    return true if @sync.nil?
    return true if stalled?

    !@sync.running? && @sync.processing_finished?
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
      p(class: "text-sm text-muted") { "Not scanned yet." }
      p(class: "mt-1 text-xs text-faint") { "It will run on its own within the scan interval, or use Sync now." }
    end
  end

  def panel
    div(class: "rounded-lg border border-line bg-ink/40 p-5") do
      header_row
      error_row if @sync.error.present?
      stale_warning if @sync.stale_count.positive?
      counts_row
      processing_row
    end
  end

  def header_row
    div(class: "mb-4 flex items-center justify-between gap-3") do
      span(class: "inline-flex items-center gap-2 text-sm text-fg") do
        span(class: "h-1.5 w-1.5 rounded-full #{status_dot}")
        plain status_label
      end
      span(class: "font-mono text-xs text-faint") { "started #{time_ago_in_words(@sync.started_at)} ago" }
    end
  end

  def status_label
    return "stalled — no worker reported back" if stalled?

    case @sync.status
    when "completed" then "completed in #{duration}"
    when "failed" then "failed after #{duration}"
    else "scanning…"
    end
  end

  def status_dot
    return "bg-amber-400" if stalled?

    case @sync.status
    when "completed" then "bg-emerald-400"
    when "failed" then "bg-red-400"
    else "bg-accent animate-pulse"
    end
  end

  def stalled?
    @sync.running? && @sync.started_at < 1.hour.ago
  end

  def duration
    seconds = @sync.duration
    return "—" if seconds.nil?

    seconds < 1 ? "under a second" : "#{seconds.round}s"
  end

  def error_row
    div(class: "mb-4 rounded border border-red-400/40 bg-red-400/5 px-3 py-2") do
      p(class: "font-mono text-xs text-red-300 break-words") { @sync.error }
    end
  end

  # The one outcome that doesn't fix itself: a failed document is retried by the
  # next scan, but a document whose source outgrew the limit just sits there
  # being wrong. Say so plainly rather than leaving it as a number in a row.
  def stale_warning
    count = @sync.stale_count
    div(class: "mb-4 rounded border border-amber-400/40 bg-amber-400/5 px-3 py-2") do
      p(class: "text-xs text-amber-200") do
        plain "#{count} #{'document'.pluralize(count)} #{count == 1 ? 'is' : 'are'} out of date: "
        plain "the source changed into something this connector can't ingest. "
        plain "Raising the size limit and re-syncing will pick #{count == 1 ? 'it' : 'them'} up."
      end
    end
  end

  # What the scan itself decided. Final — nothing changes these after the scan
  # returns. Several of these words carry a distinction that isn't guessable from
  # the label alone (skipped vs stale vs errored especially), so each one explains
  # itself on hover.
  def counts_row
    div(class: "grid grid-cols-4 gap-x-4 gap-y-3 sm:grid-cols-8") do
      count_cell("found", @sync.found_count)
      count_cell("created", @sync.created_count)
      count_cell("updated", @sync.updated_count)
      count_cell("unchanged", @sync.unchanged_count)
      count_cell("removed", @sync.removed_count)
      count_cell("skipped", @sync.skipped_count)
      count_cell("stale", @sync.stale_count, warn: true)
      count_cell("errored", @sync.failed_count)
    end
  end

  def count_cell(label, value, warn: false)
    colour = if value.zero?
      "text-faint"
    elsif warn
      "text-amber-300"
    else
      "text-fg"
    end

    # The dotted underline is the only cue that there is anything to hover; a
    # bare title attribute is undiscoverable.
    div(title: HINTS.fetch(label), class: "cursor-help") do
      div(class: "font-mono text-lg tabular-nums #{colour}") { value.to_s }
      div(class: "text-xs text-faint underline decoration-dotted decoration-line-2 underline-offset-4") { label }
    end
  end

  # Where the documents this scan produced have got to. Queried from the
  # documents, so it stays true even if a worker died mid-pipeline.
  #
  # Worth being careful with the wording: this sits directly under "completed in
  # under a second", and the two are about different things. The scan is
  # finished; the documents it found are not.
  def processing_row
    counts = @sync.pipeline_statuses
    total = counts.values.sum
    return if total.zero?

    div(class: "mt-5 border-t border-line pt-4") do
      div(class: "mb-2 flex items-center justify-between gap-3") do
        span(class: "shrink-0 text-xs text-muted") { "Processing" }
        span(class: "font-mono text-xs text-faint") { processing_label(counts, total) }
      end
      meter(counts, total)
    end
  end

  # One phrasing for both states, counting *forwards* to match the bar filling
  # up. "N of M documents" on its own would be ambiguous about direction —
  # whether N is done or left — so it says which.
  #
  # "from this scan" rather than "found": the denominator is what this scan
  # actually ingested (created + updated), which is not the `found` count. A scan
  # that found 10 and ingested 2 would otherwise claim "0 of 2 found documents"
  # with a 10 sitting in the row above it.
  #
  # Counting what actually reached `processed` also stops the finished case
  # overstating itself: an earlier wording said "3 documents done" even when two
  # of the three had failed.
  def processing_label(counts, total)
    processed = counts.fetch("processed", 0)
    failed = counts.fetch("failed", 0)
    label = "#{processed} of #{total} #{'document'.pluralize(total)} from this scan processed"

    failed.positive? ? "#{label} · #{failed} failed" : label
  end

  def meter(counts, total)
    div(class: "flex h-1.5 w-full overflow-hidden rounded-full bg-line/50") do
      METER.each_key do |status|
        count = counts[status].to_i
        next if count.zero?

        div(
          class: "h-full #{METER[status]}",
          style: "width: #{(count.to_f / total * 100).round(2)}%",
          title: "#{count} #{status}"
        )
      end
    end
  end
end
