# frozen_string_literal: true

class Views::Chat::Index < Views::Base
  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Chat" }
      p(class: "mt-1 text-sm text-muted") { "Talk to your archive — retrieval runs as a tool the model calls." }
    end

    div(class: "rounded-lg border border-line bg-ink/40 px-6 py-12 text-center") do
      p(class: "text-sm text-muted") { "Not built yet." }
      p(class: "mt-2 text-sm text-faint") { "Next up: a streaming chat where you pick which collections to draw on." }
    end
  end

  private

  def page_title = "Chat"
end
