# frozen_string_literal: true

class Views::Documents::Index < Views::Base
  def initialize(documents:)
    @documents = documents
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Documents" }
      p(class: "mt-1 text-sm text-muted") { "Upload a file to ingest it into the archive." }
    end

    upload_form
    document_list
  end

  private

  def page_title = "Documents"

  def upload_form
    form(
      action: documents_path,
      method: "post",
      enctype: "multipart/form-data",
      class: "mb-10 rounded-lg border border-line bg-ink/40 p-5 shadow-sm flex items-center gap-4"
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(
        type: "file",
        name: "file",
        required: true,
        class: "block w-full text-sm text-muted file:mr-4 file:rounded file:border-0 " \
               "file:bg-accent file:px-4 file:py-2 file:text-sm file:font-medium file:text-void " \
               "hover:file:bg-accent-dim file:cursor-pointer"
      )
      button(
        type: "submit",
        class: "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Upload" }
    end
  end

  # A file uploaded from the form above lands here still pending and is processed
  # in the background, so the badges this renders are stale the moment they're
  # sent. Poll until every row has settled.
  def document_list
    div(id: "documents", data: progress_data(terminal: @documents.all?(&:settled?))) do
      if @documents.any?
        ul(class: "divide-y divide-line rounded-lg border border-line bg-ink/40") do
          @documents.each { |document| document_row(document) }
        end
      else
        p(class: "text-sm text-faint") { "No documents yet." }
      end
    end
  end

  def document_row(document)
    li do
      a(href: document_path(document), class: "flex items-center justify-between gap-3 px-5 py-4 hover:bg-ink/60 transition-colors") do
        span(class: "truncate text-sm font-medium text-fg") { document.title }
        render Views::Documents::StatusBadge.new(status: document.status)
      end
    end
  end
end
