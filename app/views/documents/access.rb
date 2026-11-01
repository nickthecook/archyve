# frozen_string_literal: true

# How a reader actually gets at a document itself, rather than the chunk-level
# view of it that Views::Documents::Show is built around. Rendered by both that
# page and a search result, because "I've found the passage, now give me the
# document" is the same request from either.
#
# Which affordance appears is a property of the *source*, not of the reader's
# role: a source that can hand out a link the browser can follow gets linked to,
# and one that can't gets downloaded from Archyve. Chat and search therefore
# work identically for a curator and a plain user — a curator's extra
# access is browsing the archive, which is a different entry point entirely.
class Views::Documents::Access < Components::Base
  def initialize(document:, class_name: nil)
    @document = document
    @class_name = class_name || "text-xs text-muted hover:text-fg transition-colors"
  end

  def view_template
    if (url = source_url)
      a(href: url, target: "_blank", rel: "noopener", class: @class_name) do
        "Open in #{@document.source.type_label}"
      end
    elsif @document.file.attached?
      a(href: download_document_path(@document), class: @class_name) { "Download" }
    else
      span(class: "text-xs text-faint") { "Unavailable" }
    end
  end

  private

  def source_url
    source = @document.source
    return unless source&.user_accessible_links?

    source.document_url(@document)
  end
end
