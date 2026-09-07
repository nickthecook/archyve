# frozen_string_literal: true

class Views::Settings::Index < Views::Base
  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Settings" }
      p(class: "mt-1 text-sm text-muted") { "Models, inference servers, and preferences." }
    end

    section_link(
      "Connectors",
      "Where documents come from — folders, and later object stores and wikis.",
      settings_connectors_path
    )

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

  # A section of settings that has its own page, as opposed to the read-only
  # rows below it.
  def section_link(title, description, href)
    a(href: href, class: "flex items-center justify-between gap-4 rounded-lg border border-line bg-ink/40 px-5 py-4 hover:border-line-2 transition-colors") do
      div do
        p(class: "text-sm font-medium text-fg") { title }
        p(class: "mt-0.5 text-xs text-faint") { description }
      end
      span(class: "shrink-0 text-muted") { "→" }
    end
  end

  def row(label, value)
    div(class: "flex items-center justify-between px-5 py-3.5") do
      dt(class: "text-sm text-muted") { label }
      dd(class: "font-mono text-sm text-fg") { value }
    end
  end
end
