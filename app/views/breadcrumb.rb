# frozen_string_literal: true

# The trail back up, above a page's heading. Every page you came *down* into
# carries one; a section root — anything reachable from the top bar — does not.
#
# A crumb is `[label, href]`, or a bare label for the page you are on:
#
#   render Views::Breadcrumb.new(["Collections", collections_path], @collection.name)
#
# The last crumb never links, whatever it was given, so no page offers a way
# back to itself. See docs/design.md.
class Views::Breadcrumb < Components::Base
  def initialize(*trail)
    @trail = trail
  end

  # A block renders as actions on the trail's row, at its right.
  def view_template(&actions)
    return trail("mb-5") unless actions

    div(class: "mb-5 flex items-center justify-between gap-4") do
      trail
      div(class: "shrink-0", &actions)
    end
  end

  private

  def trail(spacing = nil)
    nav(class: ["flex flex-wrap items-center gap-2 text-xs text-faint", spacing]) do
      @trail.each_with_index do |crumb, index|
        span { "›" } if index.positive?
        step(crumb, last: index == @trail.length - 1)
      end
    end
  end

  def step(crumb, last:)
    label, href = crumb

    if href && !last
      a(href: href, class: "hover:text-muted transition-colors") { label }
    else
      span(class: "text-muted") { label }
    end
  end
end
