# frozen_string_literal: true

# A row on a menu page, where every entry leads elsewhere — so none of them gets
# the accent rail a Views::Doorway has. See docs/design.md.
#
# The icon is the content block, as with Views::Doorway.
class Views::MenuCard < Components::Base
  def initialize(href:, title:, description: nil, meta: nil)
    @href = href
    @title = title
    @description = description
    @meta = meta
  end

  def view_template
    a(
      href: @href,
      class: "flex items-center gap-4 rounded-lg border border-line bg-ink/40 px-5 py-4 hover:border-line-2 transition-colors"
    ) do
      span(class: "grid h-9 w-9 shrink-0 place-items-center rounded bg-accent/10 text-accent") { yield }
      div(class: "min-w-0 flex-1") do
        p(class: "text-sm font-medium text-fg") { @title }
        p(class: "mt-0.5 text-xs text-faint") { @description } if @description
      end
      span(class: "shrink-0 font-mono tabular-nums text-xs text-muted") { @meta } if @meta
    end
  end
end
