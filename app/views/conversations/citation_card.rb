# frozen_string_literal: true

# What a citation marker opens: the passage, and the ways to the document it
# came from. See docs/architecture.md on why the snippet is shown even when
# neither way is open to the reader.
class Views::Conversations::CitationCard < Components::Base
  ACTION = "block px-4 py-2 text-sm text-muted hover:text-fg hover:bg-void/40 transition-colors"

  def initialize(hit:, id:)
    @hit = hit
    @id = id
  end

  def view_template
    div(
      id: @id,
      popover: "auto",
      style: "position-anchor: --#{@id}",
      class: "w-80 max-w-[calc(100vw-2rem)] rounded-lg border border-line-2 bg-ink p-0 font-sans text-muted shadow-lg " \
             "supports-[position-area:bottom]:inset-auto supports-[position-area:bottom]:my-1 " \
             "supports-[position-area:bottom]:mx-0 [position-area:bottom_span-right] " \
             "[position-try-fallbacks:flip-block,flip-inline]"
    ) do
      heading
      p(class: "max-h-48 overflow-y-auto border-y border-line/60 px-4 py-2.5 text-[0.8125rem] leading-relaxed " \
               "whitespace-pre-line break-words") { @hit.snippet }
      actions
    end
  end

  private

  def heading
    div(class: "px-4 py-2.5") do
      span(class: "block truncate text-[0.8125rem] font-medium text-fg") { @hit.title }
      span(class: "block truncate text-[0.7rem] text-faint") { @hit.heading_path } if @hit.heading_path.present?
    end
  end

  def actions
    div(class: "py-1") do
      if (url = @hit.external_url)
        a(href: url, target: "_blank", rel: "noopener", class: ACTION) do
          plain "Open in #{@hit.document.source.type_label} "
          span(aria_hidden: "true") { "↗" }
        end
      end
      a(href: @hit.href, class: ACTION) { "View passage in Archyve" } if @hit.followable?
      span(class: "block px-4 py-2 text-xs text-faint") { "Cannot link to this source" } unless url || @hit.followable?
    end
  end
end
