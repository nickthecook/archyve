# frozen_string_literal: true

# Who you are, and what only you can do: preferences and the way out. In the
# top bar on every contained page, and in the landing's footer, which has no
# top bar — there it opens upwards, centred on itself.
class Views::AccountMenu < Components::Base
  SUMMARY = {
    header: "text-sm text-muted hover:text-fg",
    footer: "text-faint hover:text-muted"
  }.freeze

  PANEL = {
    header: "right-0 mt-2",
    footer: "bottom-full left-1/2 mb-2 -translate-x-1/2"
  }.freeze

  def initialize(placement: :header)
    @placement = placement
  end

  def view_template
    details(class: "relative") do
      summary(class: "cursor-pointer list-none transition-colors #{SUMMARY.fetch(@placement)}") do
        header? ? squeezable_address : plain(Current.user.email_address)
      end
      div(class: "absolute z-10 w-56 rounded-lg border border-line-2 bg-ink py-1 font-sans shadow-lg " \
                 "#{PANEL.fetch(@placement)}") do
        if header?
          span(class: "block truncate border-b border-line/60 px-4 py-2 text-xs text-faint sm:hidden") do
            Current.user.email_address
          end
        end
        menu_link("Preferences", account_path)
        menu_link("Jobs", mission_control_jobs_path) if may?(:admin)
        sign_out
      end
    end
  end

  private

  def header? = @placement == :header

  # The address is the widest thing in the top bar and the least load-bearing —
  # on a phone it alone is the difference between fitting and scrolling. The
  # initial stands in for it; the menu still says who you are. The footer stacks
  # on a phone instead, so it keeps the address.
  def squeezable_address
    span(class: "hidden sm:inline") { Current.user.email_address }
    span(class: "grid h-7 w-7 place-items-center rounded border border-line font-mono text-xs sm:hidden") { initial }
  end

  def initial
    Current.user.email_address.to_s.strip[0].to_s.upcase
  end

  def menu_link(label, href)
    a(href: href, class: "block px-4 py-2 text-left text-sm text-muted hover:text-fg hover:bg-void/40 transition-colors") { label }
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
end
