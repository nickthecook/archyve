# frozen_string_literal: true

# What the pipeline said when it gave up on one document, for the person whose
# job it is to do something about it.
#
# Operator-only, and a region of its own with a Turbo stream of its own — see
# the note on Document#broadcast_diagnostics_change for why it can't be a
# branch inside Views::Documents::Detail. Like Detail it is rendered from the
# model during a broadcast, so it stays helper-free: no routes, no tokens, no
# Current.user. It shows facts; the control that acts on them is rendered by
# Views::Documents::Show, in a request, where those things exist.
class Views::Documents::Diagnostics < Components::Base
  def self.dom_id(document) = "#{ActionView::RecordIdentifier.dom_id(document)}_diagnostics"

  def initialize(document:)
    @document = document
  end

  def view_template
    # Rendered even when there is nothing to say: an empty region is what the
    # broadcast and the poll both need as a landing place, and a document that
    # fails while someone watches has somewhere to put the news.
    div(id: self.class.dom_id(@document), class: "mt-4") do
      facts if @document.failed? || @document.shortfall?
    end
  end

  private

  # The raw line, not a paraphrase. This is the thing that was missing in
  # production, and whoever reads it is going to paste it into a terminal or a
  # search — so it keeps the exception class, and it keeps monospace. Styled
  # after Views::Sources::LastScan's error row, which is the same idea one
  # level up.
  #
  # Amber rather than red when the document came through with a shortfall: it
  # is in the archive and being searched, and colouring it like an outage would
  # send someone to fix a pipeline that is working.
  def facts
    div(class: "rounded border px-3 py-2 #{tone}") do
      p(class: "font-mono text-xs uppercase tracking-wide #{headline_tone}") { headline }
      p(class: "mt-1 font-mono text-xs #{detail_tone} break-words") { @document.outcome_detail } if detail?
    end
  end

  def failed? = @document.failed?

  def tone = failed? ? "border-red-400/40 bg-red-400/5" : "border-amber-400/40 bg-amber-400/5"
  def headline_tone = failed? ? "text-red-400/80" : "text-amber-400/80"
  def detail_tone = failed? ? "text-red-300" : "text-amber-300"

  # Stage and kind together, because each answers half of it: where the pipeline
  # was, and what happened there. Either may be absent on a document that failed
  # before they were recorded.
  def headline
    [@document.outcome_stage, @document.outcome_kind].compact_blank.join(" · ").presence ||
      "failed — no diagnosis was recorded"
  end

  def detail? = @document.outcome_detail.present?
end
