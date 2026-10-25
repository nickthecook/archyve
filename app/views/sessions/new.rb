# frozen_string_literal: true

# The way in. Full-bleed rather than contained: Views::Chrome links to
# Collections, Chat and Settings, none of which a signed-out visitor can reach,
# so the nav would be three dead ends. That also means the layout isn't
# rendering flash for us — this page does its own, since a failed sign-in
# arrives as one.
class Views::Sessions::New < Views::Base
  include Phlex::Rails::Helpers::Flash

  def view_template
    div(class: "min-h-screen flex items-center justify-center px-5 py-16") do
      div(class: "w-full max-w-sm") do
        masthead
        alerts
        if Sso.configured?
          sso_button
          password_disclosure
        else
          form_panel
        end
      end
    end
  end

  private

  def page_title = "Sign in"
  def contained? = false

  def masthead
    div(class: "mb-8 flex flex-col items-center gap-3") do
      render Views::BrandMark.new(
        mark_class: "w-8 h-[27px] overflow-visible",
        name_class: "text-xs font-semibold tracking-[0.34em] text-muted"
      )
    end
  end

  def alerts
    flash.each do |type, message|
      color = type.to_sym == :alert ? "bg-red-500/10 text-red-300 border-red-500/30" : "bg-accent/10 text-accent border-accent/30"
      div(class: "mb-5 rounded border px-4 py-3 text-sm #{color}") { message }
    end
  end

  # The one solid brass control on the surface, per the accent ladder in
  # docs/design.md. Its own form: it POSTs elsewhere, and a form can't nest.
  def sso_button
    # Turbo off: the response is a redirect to the IdP on another origin, and
    # Turbo would follow it with fetch, which CORS refuses. This has to be a
    # top-level browser navigation.
    form(action: sso_sign_in_path, method: "post", class: "mb-5", data: { turbo: "false" }) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "w-full rounded bg-accent px-4 py-2.5 text-sm font-medium text-void " \
               "hover:bg-accent-dim transition-colors"
      ) { "Sign in with SSO" }
    end
  end

  # Break-glass, so it is present but quiet. Opened when a flash is showing,
  # since the only way to see one here is to have just tried a password.
  def password_disclosure
    details(class: "group", open: flash[:alert].present?) do
      summary(class: "flex cursor-pointer list-none items-center gap-2 text-sm text-muted hover:text-fg transition-colors") do
        chevron
        plain "Use a password"
      end

      div(class: "mt-4") { form_panel }
    end
  end

  def chevron
    svg(
      class: "shrink-0 text-faint transition-transform group-open:rotate-90",
      width: "14", height: "14", viewbox: "0 0 24 24", fill: "none",
      stroke: "currentColor", stroke_width: "2", aria_hidden: "true"
    ) { |s| s.path(d: "M9 18l6-6-6-6") }
  end

  def form_panel
    form(action: session_path, method: "post", class: "flex flex-col gap-5 rounded-lg border border-line bg-ink/40 p-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      field("Email") do
        text_input(:email_address, type: "email", autocomplete: "username", autofocus: true)
      end
      field("Password") do
        text_input(:password, type: "password", autocomplete: "current-password")
      end

      button(type: "submit", class: submit_class) { "Sign in" }
    end
  end

  # Solid only when it is the way in. With SSO configured the brass belongs to
  # the SSO button, and two solid buttons on one surface means neither reads as
  # the primary one.
  def submit_class
    if Sso.configured?
      "rounded border border-accent/60 bg-accent/10 px-4 py-2 text-sm font-medium text-accent " \
        "hover:bg-accent/20 hover:border-accent transition-colors"
    else
      "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
    end
  end

  def field(label_text)
    div do
      label(class: "block mb-2 text-sm font-medium text-fg", for: "session_#{label_text.downcase}") { label_text }
      yield
    end
  end

  def text_input(name, type:, autocomplete:, autofocus: false)
    input(
      type: type,
      id: "session_#{name == :email_address ? 'email' : name}",
      name: name.to_s,
      autocomplete: autocomplete,
      autofocus: autofocus,
      required: true,
      class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
    )
  end
end
