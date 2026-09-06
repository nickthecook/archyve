# frozen_string_literal: true

# Slim top bar for contained pages — the triangle mark returns home, and the
# three sections stand in for the landing's facets. No sidebar.
class Views::Chrome < Components::Base
  NAV = [["Collections", :collections_path], ["Chat", :chat_path], ["Settings", :settings_path]].freeze

  def view_template
    header(class: "border-b border-line/60") do
      div(class: "mx-auto max-w-3xl px-5 h-14 flex items-center justify-between") do
        a(href: root_path, class: "flex items-center gap-2.5 group") do
          mark
          span(class: "text-xs font-semibold tracking-[0.34em] text-muted group-hover:text-fg transition-colors") { "ARCHYVE" }
        end
        nav(class: "flex items-center gap-6 text-sm") do
          NAV.each { |label, path| nav_link(label, public_send(path)) }
        end
      end
    end
  end

  private

  def nav_link(label, href)
    active = current_page?(href)
    a(href: href, class: "transition-colors #{active ? 'text-accent' : 'text-muted hover:text-fg'}") { label }
  end

  def mark
    svg(viewbox: "0 0 24 20", class: "w-[18px] h-[16px] overflow-visible", aria_hidden: "true") do |s|
      s.polygon(points: "12,1 23,19 1,19", fill: "none", stroke: "#e6b455", stroke_width: "1.4")
      s.polygon(points: "12,7 17.5,17 6.5,17", fill: "none", stroke: "#e6b455", stroke_width: "0.8", opacity: "0.5")
    end
  end
end
