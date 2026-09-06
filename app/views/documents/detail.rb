# frozen_string_literal: true

# The live region of a document's show page: status + chunks. Kept helper-free
# (dom_id computed directly, no route/view helpers) so the Document model can
# render it to a string and broadcast it over Turbo Streams when status changes.
class Views::Documents::Detail < Components::Base
  def initialize(document:)
    @document = document
  end

  def view_template
    div(id: ActionView::RecordIdentifier.dom_id(@document)) do
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
      span(class: "text-sm text-slate-500") { "Extracting, chunking and embedding…" }
    elsif @document.processed?
      count = @document.chunks.size
      span(class: "text-sm text-slate-500") { "#{count} #{'chunk'.pluralize(count)}" }
    end
  end

  def failed_note
    p(class: "text-sm text-red-700") { "Processing failed — check the logs and try re-uploading." }
  end

  def chunks
    div(class: "space-y-4") do
      @document.chunks.order(:position).each { |chunk| chunk_card(chunk) }
    end
  end

  def chunk_card(chunk)
    breadcrumb = Array(chunk.structure["heading_path"]).join(" › ")
    article(class: "rounded-lg border border-slate-200 bg-white p-4 shadow-sm") do
      header(class: "mb-2 flex items-center justify-between gap-3") do
        span(class: "text-xs font-semibold uppercase tracking-wide text-slate-400") { "Chunk #{chunk.position + 1}" }
        span(class: "text-xs text-slate-400 truncate") { breadcrumb } if breadcrumb.present?
      end
      pre(class: "whitespace-pre-wrap font-sans text-sm leading-relaxed text-slate-700") { chunk.content }
    end
  end
end
