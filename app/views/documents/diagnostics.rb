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
      facts if @document.failed?
    end
  end

  private

  # The raw line, not a paraphrase. This is the thing that was missing in
  # production, and whoever reads it is going to paste it into a terminal or a
  # search — so it keeps the exception class, and it keeps monospace. Styled
  # after Views::Sources::LastScan's error row, which is the same idea one
  # level up.
  def facts
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-3 py-2") do
      p(class: "font-mono text-xs uppercase tracking-wide text-red-400/80") { headline }
      p(class: "mt-1 font-mono text-xs text-red-300 break-words") { @document.failure_detail } if detail?
    end
  end

  # Stage and kind together, because each answers half of it: where the pipeline
  # stopped, and what stopped it. Either may be absent on a document that failed
  # before they were recorded.
  def headline
    [@document.failure_stage, @document.failure_kind].compact_blank.join(" · ").presence ||
      "failed — no diagnosis was recorded"
  end

  def detail? = @document.failure_detail.present?
end
