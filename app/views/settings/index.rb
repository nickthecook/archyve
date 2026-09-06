# frozen_string_literal: true

class Views::Settings::Index < Views::Base
  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Settings" }
      p(class: "mt-1 text-sm text-muted") { "Models, inference servers, and preferences." }
    end

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

  def row(label, value)
    div(class: "flex items-center justify-between px-5 py-3.5") do
      dt(class: "text-sm text-muted") { label }
      dd(class: "font-mono text-sm text-fg") { value }
    end
  end
end
