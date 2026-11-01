# frozen_string_literal: true

# Slim top bar for contained pages — the triangle mark returns home, and the
# sections stand in for the landing's facets. No sidebar.
class Views::Chrome < Components::Base
  # Label, path helper, and the minimum role that can reach it. Filtered rather
  # than shown-and-refused: a link that bounces you is worse than no link. The
  # landing's facets are filtered the same way.
  NAV = [
    ["Collections", :collections_path, :curator],
    ["Chat", :conversations_path, :user],
    ["Settings", :settings_path, :admin],
    ["Help", :help_path, :user]
  ].freeze

  def initialize(wide: false)
    @wide = wide
  end

  def view_template
    header(class: "border-b border-line/60") do
      # Wraps rather than overflows: on a narrow screen the sections drop to a
      # second line under the wordmark. `min-h-14` keeps the bar its full height
      # once they fit again — without it the bar shrinks to its content.
      div(class: "mx-auto #{@wide ? 'max-w-6xl' : 'max-w-3xl'} px-5 flex min-h-14 flex-wrap items-center justify-between gap-x-3 gap-y-2 py-2 sm:gap-x-6") do
        a(href: root_path, class: "flex items-center gap-2.5 group") do
          render Views::BrandMark.new(
            mark_class: "w-[18px] h-[16px] overflow-visible",
            logo_class: "h-6 w-auto max-w-40 object-contain",
            name_class: "text-xs font-semibold tracking-[0.34em] text-muted group-hover:text-fg transition-colors"
          )
        end
        div(class: "flex items-center gap-3 sm:gap-6") do
          nav(class: "flex items-center gap-3 text-sm sm:gap-6") do
            visible_nav.each { |label, path, _| nav_link(label, public_send(path)) }
          end
          render Views::AccountMenu.new if Current.user
        end
      end
    end
  end

  private

  def visible_nav
    NAV.select { |_, _, minimum| may?(minimum) }
  end

  def nav_link(label, href)
    active = current_page?(href)
    a(href: href, class: "transition-colors #{active ? 'text-accent' : 'text-muted hover:text-fg'}") { label }
  end
end
