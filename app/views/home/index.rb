# frozen_string_literal: true

# The landing: the archive corridor. The search is the way in (a real query),
# the three facets are the sections, and the corridor dollies as you type — the
# motion lives in corridor_controller.js.
class Views::Home::Index < Views::Base
  def initialize(stats:)
    @stats = stats
  end

  def view_template
    div(
      class: "corridor-stage",
      data: { controller: "corridor", action: "pointermove@window->corridor#peer pointerleave@window->corridor#rest" }
    ) do
      brand
      hall
      facet("documents", "Documents", documents_path, "#{@stats[:collections]} collections · #{@stats[:documents]} documents")
      facet("chat", "Chat", chat_path, @stats[:last_chat] || "start a conversation")
      facet("settings", "Settings", settings_path, "#{@stats[:embedding_model]} · #{@stats[:host]}")
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
        search
      end
    end
  end

  def search
    div(class: "search reveal", style: "animation-delay:.4s") do
      form(action: search_path, method: "get") do
        label(class: "search-field") do
          search_icon
          input(
            type: "text", name: "q", placeholder: "Search your archive",
            aria_label: "Search your archive", autocomplete: "off",
            data: { corridor_target: "input", action: "input->corridor#step focus->corridor#light blur->corridor#dim" }
          )
          kbd { "↵" }
        end
      end
      p(class: "search-hint") { "Ask anything across every collection" }
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

  def status
    div(class: "status reveal", style: "animation-delay:.9s") do
      span do
        span(class: "dot") { "●" }
        plain(" #{@stats[:host]} connected")
      end
      span { "embedding: #{@stats[:embedding_model]}" }
      span { "pgvector · #{@stats[:chunks]} chunks" }
    end
  end
end
