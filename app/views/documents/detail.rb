# frozen_string_literal: true

# The live region of a document's show page: status + chunks. Kept helper-free
# (dom_id computed directly, no route/view helpers) so the Document model can
# render it to a string and broadcast it over Turbo Streams when status changes.
class Views::Documents::Detail < Components::Base
  def initialize(document:)
    @document = document
  end

  def view_template
    div(
      id: ActionView::RecordIdentifier.dom_id(@document),
      data: progress_data(
        terminal: @document.settled?,
        also: [Views::Documents::Diagnostics.dom_id(@document)],
        controller: "progress chunk-highlight"
      )
    ) do
      div(class: "flex items-center gap-3 mb-6") do
        render Views::Documents::StatusBadge.new(status: @document.status)
        note
      end

      failed_note if @document.failed?
      chunks if @document.processed?
    end
  end

  private

  def note
    if @document.pending? || @document.processing?
      span(class: "text-sm text-muted") { "Extracting, chunking and embedding…" }
    elsif @document.processed?
      count = @document.chunks.size
      span(class: "text-sm text-muted") { "#{count} #{'chunk'.pluralize(count)}" }
    end
  end

  # What a reader is told: one sentence, in terms of what happened to *their*
  # document. The facts behind it — which stage, which service, the raw error —
  # are the operator's, and live in Views::Documents::Diagnostics.
  #
  # Keyed on failure_kind rather than composed from it so each sentence can be
  # written rather than assembled; "couldn't be read" and "didn't respond" are
  # different news, not different nouns in one template.
  SENTENCES = {
    "missing_file" => "The file behind this document is missing, so there was nothing to process.",
    "unreachable" => "A service Archyve depends on didn't respond, so this couldn't be processed.",
    "conversion_rejected" => "This file couldn't be read — it may be corrupt, empty, or in a format Archyve can't open.",
    "not_configured" => "Archyve isn't set up to index documents yet, so this couldn't be processed.",
    "dimension_mismatch" => "The embedding model returned something Archyve couldn't store."
  }.freeze

  # Covers `internal` and, just as importantly, documents that failed before any
  # of this was recorded.
  UNCLASSIFIED = "Processing failed.".freeze

  def failed_note
    p(class: "text-sm text-red-300") { SENTENCES.fetch(@document.failure_kind, UNCLASSIFIED) }
  end

  def chunks
    div(class: "space-y-4") do
      @document.chunks.order(:position).each { |chunk| chunk_card(chunk) }
    end
  end

  def chunk_card(chunk)
    breadcrumb = Array(chunk.structure["heading_path"]).join(" › ")
    # id + scroll margin so a search result or a chat citation can deep-link
    # straight to this chunk. (The flash on arrival is done in JS — see
    # chunk_highlight_controller — because Turbo's pushState navigation doesn't
    # trigger the CSS :target pseudo-class.)
    article(
      id: chunk.anchor,
      class: "scroll-mt-6 rounded-lg border border-line bg-ink/40 p-4"
    ) do
      header(class: "mb-2 flex items-center justify-between gap-3") do
        span(class: "text-xs font-semibold uppercase tracking-wide text-faint") { "Chunk #{chunk.position + 1}" }
        span(class: "text-xs text-faint truncate") { breadcrumb } if breadcrumb.present?
      end
      pre(class: "whitespace-pre-wrap font-sans text-sm leading-relaxed text-muted") { chunk.content }
    end
  end
end
