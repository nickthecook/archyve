# frozen_string_literal: true

# The landing: the archive corridor. The bar is the way in (a real question),
# the three facets are the sections, and the corridor's motion lives in
# corridor_controller.js.
class Views::Home::Index < Views::Base
  include Phlex::Rails::Helpers::Flash

  # AGPL §13: a modified deployment must offer users its own source, so forks change this.
  SOURCE_URL = "https://github.com/nickthecook/archyve"

  def initialize(stats:, unavailable: nil)
    @stats = stats
    @unavailable = unavailable
  end

  def view_template
    flash_banner
    div(
      class: "corridor-stage",
      data: { controller: "corridor", action: "pointermove@window->corridor#peer pointerleave@window->corridor#rest motion:toggled@window->corridor#motion" }
    ) do
      brand
      hall
      # Each facet is absolutely positioned by its own class, so a role that
      # can't reach one simply leaves that corner of the corridor empty.
      if may?(:curator)
        facet("documents", "Collections", collections_path, "#{@stats[:collections]} collections · #{@stats[:documents]} documents")
      end
      facet("chat", "Chat", conversations_path, @stats[:last_chat] || "see past chats")
      if may?(:admin)
        facet("settings", "Settings", settings_path, inference_glimpse)
      end
      status
    end
  end

  private

  def page_title = nil
  def contained? = false

  # The landing skips the layout's frame, which is where flash messages are
  # drawn, and a refused role gate redirects here.
  def flash_banner
    message = flash[:alert] || flash[:notice]
    return if message.blank?

    div(
      role: "status",
      class: "landing-banner flex items-center justify-center border-b border-accent/30 bg-accent/10 px-4 text-sm text-accent"
    ) do
      span(class: "truncate") { message }
    end
  end

  def brand
    div(class: "brand reveal", style: "animation-delay:.1s") do
      render Views::BrandMark.new(name_class: "brand-name")
    end
  end

  def hall
    div(class: "hall") do
      # Outside the hall's frame, which is capped at 660px.
      landing_image(fill: true) if Brand.current.fill_screen?
      div(class: "hall-inner") do
        backdrop
        threshold
      end
    end
  end

  def backdrop
    brand = Brand.current
    if brand.corridor?
      svg(
        class: "rings reveal", viewbox: "0 0 600 520", preserveaspectratio: "xMidYMid meet",
        aria_hidden: "true", style: "animation-delay:.2s", data: { corridor_target: "rings" }
      )
      div(class: "glow")
    elsif brand.landing_image? && !brand.fill_screen?
      landing_image
    end
  end

  def landing_image(fill: false)
    brand = Brand.current
    render Views::ThemedImage.new(
      default: brand.landing_image, light: brand.landing_image_light, alt: "",
      class: ["hall-image reveal", ("fill" if fill), ("faded" if brand.landing_image_fade)], style: "animation-delay:.2s"
    )
  end

  # The lit threshold at the end of the hall. It asks rather than searches: an
  # answer drawn from the archive beats a list of chunks, and retrieval still
  # happens — as a tool the model calls, which the transcript then shows.
  def threshold
    div(class: "ask reveal", style: "animation-delay:.4s") do
      @unavailable ? search_form : ask_form
    end
  end

  # One column, so the disclaimer follows the hint however many lines it wraps to.
  def below_field(&hint)
    div(class: ["ask-below", ("shaded" if shade_disclaimer?)]) do
      p(class: "ask-hint", &hint) if hint
      render Views::Disclaimer.new(css: "ask-disclaimer")
    end
  end

  def shade_disclaimer?
    brand = Brand.current
    brand.disclaimer.present? && brand.backdrop?
  end

  def ask_form
    form(action: conversations_path, method: "post") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      field(name: "message", placeholder: Brand.current.ask_placeholder) { ask_icon }
      below_field
    end
  end

  # No chat model, so the bar does the thing that still works. A bar that posted
  # a question nothing could answer would be the one dishonest thing in the
  # corridor — and the hint says which, since the status strip only hints at it.
  def search_form
    form(action: search_path, method: "get") do
      field(name: "q", placeholder: "Search your archive") { search_icon }
      below_field { @unavailable }
    end
  end

  # Both bars are the same threshold: same lit field, same corridor wiring, so
  # the only difference a reader sees is what it is called and where it goes.
  def field(name:, placeholder:, &icon)
    label(class: "ask-field") do
      icon.call
      input(
        type: "text", name: name, placeholder: placeholder,
        aria_label: placeholder, autocomplete: "off",
        data: { corridor_target: "input", action: "focus->corridor#light blur->corridor#dim" }
      )
      kbd { "↵" }
    end
  end

  # A bubble, sharp-cornered like the brand mark: this is the one place in the
  # app where you say something rather than look something up.
  def ask_icon
    svg(class: "icon", width: "17", height: "17", viewbox: "0 0 24 24", fill: "none",
        stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "M4 4h16v12H9l-5 4V4Z")
    end
  end

  def search_icon
    svg(class: "icon", width: "17", height: "17", viewbox: "0 0 24 24", fill: "none",
        stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.circle(cx: "11", cy: "11", r: "7")
      s.path(d: "m20 20-3.5-3.5")
    end
  end

  def facet(kind, name, href, glimpse)
    a(class: "facet #{kind} reveal", href: href, style: "animation-delay:.6s") do
      span(class: "name") { name }
      span(class: "glimpse") { glimpse }
    end
  end

  # A fresh install has no inference server at all, so the corridor has to have
  # something honest to say before anything is configured.
  def inference_glimpse
    return "inference not configured" if @stats[:embedding_model].nil?

    [@stats[:embedding_model], @stats[:host]].compact.join(" · ")
  end

  def status
    div(class: "status reveal", style: "animation-delay:.9s") do
      render Views::AccountMenu.new(placement: :footer) if Current.user
      a(href: help_path, class: "status-link") { "Help" }
      a(href: SOURCE_URL, class: "status-link") { "Source" }
      motion_toggle if Brand.current.corridor?
      render Views::ThemeToggle.new(classes: "status-link")
    end
  end

  def motion_toggle
    # Views::Settings::Switch's look, but over a real checkbox: the state lives in
    # the browser, so CSS has to follow it rather than the server.
    label(class: "motion-toggle group", data: { controller: "motion" }) do
      input(
        type: "checkbox", role: "switch", class: "sr-only", checked: cookies[:reduce_motion] == "1",
        data: { motion_target: "checkbox", action: "motion#toggle" }
      )
      span(class: "relative inline-flex h-5 w-9 items-center rounded-full border border-line bg-void transition-colors " \
                  "group-hover:border-line-2 group-has-[:checked]:border-accent group-has-[:checked]:bg-accent " \
                  "group-has-[:focus-visible]:ring-1 group-has-[:focus-visible]:ring-accent") do
        span(class: "block h-3.5 w-3.5 translate-x-[3px] rounded-full bg-muted transition-transform " \
                    "group-has-[:checked]:translate-x-[18px] group-has-[:checked]:bg-on-accent")
      end
      span { "reduce motion" }
    end
  end
end
