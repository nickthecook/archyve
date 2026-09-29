# frozen_string_literal: true

# The live region for re-extracting a source's stored documents: start it, watch
# it, stop it.
#
# Keyed on the source rather than the run, so the target outlives any one run —
# the same arrangement Views::Sources::LastScan has, and for the same reason.
#
# Polled, not broadcast. The numbers here move once per document, and
# re-rendering this panel per status change across a few thousand documents
# would be thousands of messages to nudge a counter nobody needs updated more
# than every couple of seconds. See the note in LastScan.
class Views::Sources::Reprocess < Components::Base
  def self.dom_id(source) = "#{ActionView::RecordIdentifier.dom_id(source)}_reprocess"

  def initialize(source:)
    @source = source
  end

  def view_template
    div(
      id: self.class.dom_id(@source),
      data: progress_data(terminal: settled?),
      class: "mb-8 rounded-lg border border-line px-5 py-4"
    ) do
      div(class: "flex items-start justify-between gap-4") do
        div(class: "min-w-0") do
          p(class: "text-sm text-fg") { run ? "Reprocessing stored documents" : "Reprocess stored documents" }
          p(class: "mt-0.5 text-xs text-faint") { explanation }
        end
        run ? stop_button : start_button
      end
      meter if run
    end
  end

  private

  def run = @run ||= @source.current_reprocess

  # One grouped count answers every number here, and the poll asks for all of
  # them every couple of seconds.
  def counts = @counts ||= @source.documents.group(:status).count

  def in_flight = counts["pending"].to_i + counts["processing"].to_i
  def failed = counts["failed"].to_i

  # Nothing left to watch: no run handing documents over, and none of this
  # source's documents still moving. A cancelled run keeps the region alive
  # until the window it already handed over has drained.
  def settled? = run.nil? && in_flight.zero?

  def explanation
    return running_explanation if run
    return last_run_explanation if last_run

    "Reprocesses every document from the file already stored. " \
      "Nothing is fetched from the source."
  end

  def running_explanation
    parts = [
      "#{number_with_delimiter(run.enqueued)} of #{number_with_delimiter(run.total)} handed over",
      "#{number_with_delimiter(in_flight)} queued up"
    ]
    parts << "#{number_with_delimiter(failed)} failed" if failed.positive?
    parts.join(" · ")
  end

  # After a run of a few thousand, reverting to the idle wording leaves no way
  # to tell "finished" from "I missed it".
  def last_run_explanation
    verdict = last_run.cancelled? ? "stopped" : "finished"
    line = "Last run #{verdict} #{time_ago_in_words(last_run.finished_at || last_run.updated_at)} ago, " \
           "#{number_with_delimiter(last_run.enqueued)} of #{number_with_delimiter(last_run.total)} handed over."
    return line unless in_flight.positive? || failed.positive?

    line + " #{number_with_delimiter(in_flight)} still queued up, #{number_with_delimiter(failed)} failed."
  end

  def last_run = @last_run ||= @source.reprocesses.where.not(finished_at: nil).order(:finished_at).last

  def meter
    div(class: "mt-3 h-1 overflow-hidden rounded-full bg-line") do
      div(class: "h-full bg-accent transition-all", style: "width: #{handed_over_percent}%")
    end
  end

  def handed_over_percent
    return 100 if run.total.zero?

    ((run.enqueued.to_f / run.total) * 100).clamp(0, 100).round
  end

  def start_button
    form(action: reprocess_source_path(@source), method: "post", class: "shrink-0") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "whitespace-nowrap rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg " \
               "hover:border-line-2 transition-colors",
        data: { turbo_confirm: confirmation }
      ) { "Reprocess all" }
    end
  end

  # The count is the whole warning: what separates this from "Sync now" is
  # invisible until you know how many documents it is about to move.
  def confirmation
    count = @source.documents.reprocessable.count
    "Reprocess #{number_with_delimiter(count)} documents? Nothing is fetched from the source."
  end

  def stop_button
    form(action: cancel_reprocess_source_path(@source), method: "post", class: "shrink-0") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "whitespace-nowrap rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg " \
               "hover:border-line-2 transition-colors"
      ) { "Stop" }
    end
  end
end
