# frozen_string_literal: true

# Slim top bar for contained pages — the triangle mark returns home, and the
# sections stand in for the landing's facets. No sidebar.
class Views::Chrome < Components::Base
  # Label, path helper, and the minimum role that can reach it. Filtered rather
  # than shown-and-refused: a link that bounces you is worse than no link. The
  # landing's facets are filtered the same way.
  NAV = [
    ["Collections", :collections_path, :operator],
    ["Chat", :conversations_path, :user],
    ["Settings", :settings_path, :admin]
  ].freeze

  def view_template
    header(class: "border-b border-line/60") do
      # Wraps rather than overflows: on a narrow screen the sections drop to a
      # second line under the wordmark. `min-h-14` keeps the bar its full height
      # once they fit again — without it the bar shrinks to its content.
      div(class: "mx-auto max-w-3xl px-5 flex min-h-14 flex-wrap items-center justify-between gap-x-3 gap-y-2 py-2 sm:gap-x-6") do
        a(href: root_path, class: "flex items-center gap-2.5 group") do
          mark
          span(class: "text-xs font-semibold tracking-[0.34em] text-muted group-hover:text-fg transition-colors") { "ARCHYVE" }
        end
        div(class: "flex items-center gap-3 sm:gap-6") do
          nav(class: "flex items-center gap-3 text-sm sm:gap-6") do
            visible_nav.each { |label, path, _| nav_link(label, public_send(path)) }
          end
          account if Current.user
        end
      end
    end
  end

  private

  def visible_nav
    NAV.select { |_, _, minimum| may?(minimum) }
  end

  # Who you are, and what only you can do: preferences and the way out. Reads
  # Current.user directly rather than a helper adapter — it is a plain
  # CurrentAttributes lookup, not the deprecated `helpers` proxy this file
  # avoids. Same details/summary disclosure as the "New collection" menu.
  def account
    details(class: "relative") do
      summary(class: "cursor-pointer list-none text-sm text-muted hover:text-fg transition-colors") do
        span(class: "hidden sm:inline") { Current.user.email_address }
        # The address is the widest thing in the bar and the least load-bearing
        # — on a phone it alone is the difference between fitting and scrolling.
        # The initial stands in for it; the menu below still says who you are.
        span(class: "grid h-7 w-7 place-items-center rounded border border-line font-mono text-xs sm:hidden") { initial }
      end
      div(class: "absolute right-0 z-10 mt-2 w-56 rounded-lg border border-line-2 bg-ink py-1 shadow-lg") do
        span(class: "block truncate border-b border-line/60 px-4 py-2 text-xs text-faint sm:hidden") do
          Current.user.email_address
        end
        menu_link("Preferences", account_path)
        menu_link("Jobs", mission_control_jobs_path) if may?(:admin)
        sign_out
      end
    end
  end

  def initial
    Current.user.email_address.to_s.strip[0].to_s.upcase
  end

  def menu_link(label, href)
    a(href: href, class: "block px-4 py-2 text-sm text-muted hover:text-fg hover:bg-void/40 transition-colors") { label }
  end

  def sign_out
    # Turbo off for the same reason as the SSO button: signing out of an SSO
    # session redirects to the IdP to end its session too, and Turbo would try
    # to follow that cross-origin redirect with fetch.
    form(action: session_path, method: "post", data: { turbo: "false" }) do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "block w-full px-4 py-2 text-left text-sm text-muted hover:text-fg hover:bg-void/40 transition-colors"
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
