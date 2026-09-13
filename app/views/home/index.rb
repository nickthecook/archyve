# frozen_string_literal: true

# The landing: the archive corridor. The bar is the way in (a real question),
# the three facets are the sections, and the corridor dollies as you type — the
# motion lives in corridor_controller.js.
class Views::Home::Index < Views::Base
  def initialize(stats:, models: [], model: nil, unavailable: nil)
    @stats = stats
    @models = models
    @model = model
    @unavailable = unavailable
  end

  def view_template
    div(
      class: "corridor-stage",
      data: { controller: "corridor", action: "pointermove@window->corridor#peer pointerleave@window->corridor#rest motion:toggled@window->corridor#motion" }
    ) do
      brand
      hall
      # Each facet is absolutely positioned by its own class, so a role that
      # can't reach one simply leaves that corner of the corridor empty.
      if may?(:operator)
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

  def brand
    div(class: "brand reveal", style: "animation-delay:.1s") do
      svg(viewbox: "0 0 24 20", aria_hidden: "true") do |s|
        s.polygon(points: "12,1 23,19 1,19", fill: "none", stroke: "#e6b455", stroke_width: "1.4")
        s.polygon(points: "12,7 17.5,17 6.5,17", fill: "none", stroke: "#e6b455", stroke_width: "0.8", opacity: "0.5")
      end
      span(class: "brand-name") { "ARCHYVE" }
    end
  end

  def hall
    div(class: "hall") do
      div(class: "hall-inner") do
        svg(
          class: "rings reveal", viewbox: "0 0 600 520", preserveaspectratio: "xMidYMid meet",
          aria_hidden: "true", style: "animation-delay:.2s", data: { corridor_target: "rings" }
        )
        div(class: "glow")
        threshold
      end
    end
  end

  # The lit threshold at the end of the hall. It asks rather than searches: an
  # answer drawn from the archive beats a list of chunks, and retrieval still
  # happens — as a tool the model calls, which the transcript then shows.
  def threshold
    div(class: "ask reveal", style: "animation-delay:.4s") do
      @unavailable ? search_form : ask_form
    end
  end

  def ask_form
    form(action: conversations_path, method: "post") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      field(name: "message", placeholder: "Consult the archive") { ask_icon }
      # The hint line is the only furniture the corridor gains, and it gains it
      # on focus rather than at rest: which model answers is worth a choice, but
      # not worth a control sitting in the threshold competing with the question.
      p(class: "ask-hint") do
        span { "Draws on everything you can read" }
        if @models.any?
          span { "·" }
          render Views::Conversations::ModelPicker.new(models: @models, selected: @model, caption: nil)
        end
      end
    end
  end

  # No chat model, so the bar does the thing that still works. A bar that posted
  # a question nothing could answer would be the one dishonest thing in the
  # corridor — and the hint says which, since the status strip only hints at it.
  def search_form
    form(action: search_path, method: "get") do
      field(name: "q", placeholder: "Search your archive") { search_icon }
      p(class: "ask-hint") { @unavailable }
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
        data: { corridor_target: "input", action: "input->corridor#step focus->corridor#light blur->corridor#dim" }
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
      span do
        span(class: "dot") { "●" }
        plain(@stats[:host] ? " #{@stats[:host]} connected" : " no inference server")
      end
      span { @stats[:embedding_model] ? "embedding: #{@stats[:embedding_model]}" : "embedding: not configured" }
      span { "pgvector · #{@stats[:chunks]} chunks" }
      motion_toggle
    end
  end

  def motion_toggle
    label(class: "motion-toggle", data: { controller: "motion" }) do
      input(
        type: "checkbox", checked: cookies[:reduce_motion] == "1",
        data: { motion_target: "checkbox", action: "motion#toggle" }
      )
      span { "reduce motion" }
    end
  end
end
