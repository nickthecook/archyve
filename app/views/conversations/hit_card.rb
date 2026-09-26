# frozen_string_literal: true

# One chunk the model was shown, as a card in the panel that shows it.
#
# The whole card is the target, not just the title. What a reader wants having
# just read a snippet is *that passage, in its document*, and the snippet is the
# part they were reading — so it should be the part they can click. Safe as one
# anchor because the card carries no actions of its own, unlike a search result.
#
# A hit whose document is gone stays a plain div. It is still the honest record
# of what the model was shown — see Hit — but there is nowhere to go, and a link
# to nothing is worse than no link.
class Views::Conversations::HitCard < Components::Base
  CARD = "block rounded border border-line bg-ink/60 px-3.5 py-3"
  # Hover on the whole card, accent on the title: the app's vocabulary for a row
  # that opens the thing it names (see the document rows in a collection).
  #
  # A *named* group, because the enclosing details is already `group` (for the
  # chevron) and Tailwind's `group-hover:` matches any ancestor carrying the
  # class — an unnamed group here would light up every title in the panel
  # whenever the pointer was anywhere inside it.
  FOLLOWABLE = "group/hit hover:border-line-2 hover:bg-ink transition-colors"

  def initialize(hit:)
    @hit = hit
  end

  def view_template
    return a(href: @hit.href, class: "#{CARD} #{FOLLOWABLE}") { body } if @hit.followable?

    div(class: CARD) { body }
  end

  private

  def body
    div(class: "mb-1 flex items-baseline gap-3") do
      span(class: "shrink-0 font-mono text-[0.7rem] text-accent tabular-nums") { @hit.handle.to_s }
      span(class: "truncate text-[0.8125rem] font-medium text-fg transition-colors group-hover/hit:text-accent") { @hit.title }
      span(class: "ml-auto shrink-0 font-mono text-[0.7rem] text-faint tabular-nums") { measure }
    end
    if @hit.heading_path.present?
      span(class: "mb-1.5 block pl-[1.9rem] text-[0.7rem] text-faint") { @hit.heading_path }
    end
    p(class: "break-words pl-[1.9rem] text-[0.8125rem] leading-relaxed text-muted") { @hit.snippet }
  end

  # Quiet, not accent, whichever of the two this is: the list is ordered by
  # fused score, so a percentage is a quality reading rather than the sort key,
  # and where a chunk sits in its document is a fact rather than a judgement.
  #
  # A read has no similarity — nothing ranked it — so it says where it came
  # from instead, which is the thing worth knowing about a chunk nobody chose.
  def measure
    @hit.similarity ? "#{@hit.similarity}%" : "##{@hit.chunk_number}"
  end
end
