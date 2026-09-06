# frozen_string_literal: true

class Views::Documents::Index < Views::Base
  def initialize(documents:)
    @documents = documents
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Documents" }
      p(class: "mt-1 text-sm text-slate-500") { "Upload a file to ingest it into the knowledge base." }
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
      class: "mb-10 rounded-lg border border-slate-200 bg-white p-5 shadow-sm flex items-center gap-4"
    ) do
      input(type: "hidden", name: "authenticity_token", value: helpers.form_authenticity_token)
      input(
        type: "file",
        name: "file",
        required: true,
        class: "block w-full text-sm text-slate-600 file:mr-4 file:rounded-md file:border-0 " \
               "file:bg-slate-900 file:px-4 file:py-2 file:text-sm file:font-medium file:text-white " \
               "hover:file:bg-slate-700 file:cursor-pointer"
      )
      button(
        type: "submit",
        class: "shrink-0 rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-700"
      ) { "Upload" }
    end
  end

  def document_list
    if @documents.any?
      ul(class: "divide-y divide-slate-200 rounded-lg border border-slate-200 bg-white shadow-sm") do
        @documents.each { |document| document_row(document) }
      end
    else
      p(class: "text-sm text-slate-400") { "No documents yet." }
    end
  end

  def document_row(document)
    li do
      a(href: document_path(document), class: "flex items-center justify-between gap-3 px-5 py-4 hover:bg-slate-50") do
        span(class: "truncate text-sm font-medium text-slate-800") { document.title }
        render Views::Documents::StatusBadge.new(status: document.status)
      end
    end
  end
end
