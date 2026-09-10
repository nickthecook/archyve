# frozen_string_literal: true

class Views::Settings::Index < Views::Base
  def initialize(people_count:)
    @people_count = people_count
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Settings" }
      p(class: "mt-1 text-sm text-muted") { "Models, inference servers, and preferences." }
    end

    # A link out of this page, so it wears the rail. The "Inference" heading
    # below does the job the rule does elsewhere — it separates *and* names
    # the zone, so a rule as well would be redundant. See docs/design.md.
    render Views::Doorway.new(
      href: settings_users_path,
      title: "People",
      description: "Who can sign in, and how much of Archyve they see.",
      meta: "#{@people_count} #{'person'.pluralize(@people_count)}"
    ) { people_icon }

    h2(class: "mt-8 mb-3 text-sm font-medium text-fg") { "Inference" }
    dl(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      row("Embedding model", Embedding::DEFAULT_MODEL)
      row("Embedding dimensions", Embedding::DIMENSIONS.to_s)
      row("Ollama endpoint", ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/v1"))
      row("Docling endpoint", ENV.fetch("DOCLING_URL", "http://localhost:5001"))
    end

    p(class: "mt-4 text-sm text-faint") { "Editing these — and admin-only options — is coming next." }
  end

  private

  def page_title = "Settings"

  def people_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.circle(cx: "9", cy: "8", r: "3.2")
      s.path(d: "M3.5 19a5.5 5.5 0 0 1 11 0")
      s.path(d: "M16 5.6a3.2 3.2 0 0 1 0 4.8M17.5 13.4A5.5 5.5 0 0 1 20.5 19")
    end
  end

  def row(label, value)
    div(class: "flex items-center justify-between px-5 py-3.5") do
      dt(class: "text-sm text-muted") { label }
      dd(class: "font-mono text-sm text-fg") { value }
    end
  end
end
