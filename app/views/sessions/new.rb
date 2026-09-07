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
        form_panel
      end
    end
  end

  private

  def page_title = "Sign in"
  def contained? = false

  def masthead
    div(class: "mb-8 flex flex-col items-center gap-3") do
      mark
      span(class: "text-xs font-semibold tracking-[0.34em] text-muted") { "ARCHYVE" }
    end
  end

  def mark
    svg(viewbox: "0 0 24 20", class: "w-8 h-[27px] overflow-visible", aria_hidden: "true") do |s|
      s.polygon(points: "12,1 23,19 1,19", fill: "none", stroke: "#e6b455", stroke_width: "1.4")
      s.polygon(points: "12,7 17.5,17 6.5,17", fill: "none", stroke: "#e6b455", stroke_width: "0.8", opacity: "0.5")
    end
  end

  def alerts
    flash.each do |type, message|
      color = type.to_sym == :alert ? "bg-red-500/10 text-red-300 border-red-500/30" : "bg-accent/10 text-accent border-accent/30"
      div(class: "mb-5 rounded border px-4 py-3 text-sm #{color}") { message }
    end
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

      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Sign in" }
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
