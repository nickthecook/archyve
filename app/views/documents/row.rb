# frozen_string_literal: true

# A document in a list: title, where it sits, status, and whichever of Remove
# and Delete the caller has decided this user may use.
class Views::Documents::Row < Components::Base
  def initialize(document:, purgeable:, removable_from: nil, show_source: true)
    @document = document
    @purgeable = purgeable
    @removable_from = removable_from
    @show_source = show_source
  end

  def view_template
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0 flex-1") do
        a(href: document_path(@document), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") { @document.title }
        provenance
      end
      div(class: "flex shrink-0 items-center gap-3") do
        render Views::Documents::StatusBadge.new(status: @document.status)
        remove_button if @removable_from
        delete_button if @purgeable
      end
    end
  end

  private

  def remove_button
    form(action: collection_document_path(@removable_from, @document), method: "post", class: "inline") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Remove" }
    end
  end

  # Outlined red rather than another quiet word: next to "Remove" the
  # difference has to be visible before you read the confirmation.
  def delete_button
    form(
      action: document_path(@document),
      method: "post",
      class: "inline",
      data: { turbo_confirm: "Permanently delete “#{@document.title}”? It leaves every collection and the archive — text, embeddings and file — and this can't be undone." }
    ) do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "rounded border border-red-400/40 px-2 py-0.5 text-xs text-red-300 hover:bg-red-400/10 transition-colors"
      ) { "Delete" }
    end
  end

  def provenance
    text = [(@document.source.name if @show_source), path_within_source].compact.join(" · ")
    p(class: "mt-1 truncate text-xs text-faint", title: text) { text } if text.present?
  end

  # Sources get named after whatever they point at, so the first segment is
  # usually the source name again — "Technology · Technology/Services".
  def path_within_source
    segments = @document.path.to_s.split("/")
    segments.shift if segments.first == @document.source.name
    segments.join("/").presence
  end
end
