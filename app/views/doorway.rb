# frozen_string_literal: true

# A link *out* of the page, shown in the zone above the rule — Archyve's
# alternative to a sidebar. It deliberately breaks the card vocabulary of the
# content below it: the accent left rail is the signal, and it only works while
# it stays rare (one per zone). See docs/design.md.
#
# The icon is supplied as the content block so each doorway can carry its own
# glyph while the frame stays identical everywhere:
#
#   render Views::Doorway.new(href: sources_path, title: "Sources", …) { source_icon }
class Views::Doorway < Components::Base
  def initialize(href:, title:, description: nil, meta: nil)
    @href = href
    @title = title
    @description = description
    @meta = meta
  end

  # Hover moves the *background*, not the border: `hover:border-line-2` sets all
  # four border colours and would paint over the accent rail.
  def view_template
    a(href: @href, class: "group flex items-center gap-4 rounded-lg border border-line border-l-2 border-l-accent bg-ink/60 px-5 py-4 hover:bg-ink transition-colors") do
      span(class: "grid h-9 w-9 shrink-0 place-items-center rounded bg-accent/10 text-accent") { yield }
      # The meta sits beside the description while both fit and drops beneath it
      # when they don't. Held at `shrink-0` it kept its full width and left the
      # description a column too narrow to read — "1 server · 3 models" is 137px
      # of a phone, and the sentence next to it wrapped onto five lines.
      #
      # `basis-56` is the floor that decides when to break, and it is deliberately
      # wide enough that every doorway breaks at the same width rather than each
      # one turning on how long its own meta happens to be.
      div(class: "flex min-w-0 flex-1 flex-wrap items-baseline gap-x-3 gap-y-1") do
        div(class: "min-w-0 flex-1 basis-56") do
          p(class: "text-sm font-medium text-fg") { @title }
          p(class: "mt-0.5 text-xs text-faint") { @description } if @description
        end
        span(class: "ml-auto font-mono tabular-nums text-xs text-muted") { @meta } if @meta
      end
      chevron
    end
  end

  private

  # Nudges right on hover — an affordance, never something to wait for.
  def chevron
    svg(
      class: "shrink-0 text-faint transition-transform group-hover:translate-x-0.5",
      width: "16", height: "16", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor",
      stroke_width: "2", aria_hidden: "true"
    ) { |s| s.path(d: "m9 6 6 6-6 6") }
  end
end
