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
        div(class: "flex items-center gap-6") do
          nav(class: "flex items-center gap-6 text-sm") do
            NAV.each { |label, path| nav_link(label, public_send(path)) }
          end
          account if Current.user
        end
      end
    end
  end

  private

  # Who you are, and the way out. Reads Current.user directly rather than a
  # helper adapter — it is a plain CurrentAttributes lookup, not the deprecated
  # `helpers` proxy the rest of this file avoids.
  def account
    div(class: "flex items-center gap-3 border-l border-line/60 pl-6") do
      span(class: "hidden sm:inline text-xs text-faint") { Current.user.email_address }
      sign_out
    end
  end

  def sign_out
    form(action: session_path, method: "post", class: "inline") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "text-sm text-muted hover:text-fg transition-colors cursor-pointer"
      ) { "Sign out" }
    end
  end

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
