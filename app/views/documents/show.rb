# frozen_string_literal: true

class Views::Documents::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(document:, back:)
    @document = document
    @back = back
  end

  # Outlined rather than solid: getting a copy *opens* something, it doesn't
  # commit anything — see the accent ladder in docs/design.md.
  ACCESS = "rounded border border-accent/60 bg-accent/10 px-3 py-1.5 text-sm font-medium " \
           "text-accent hover:border-accent hover:bg-accent/20 transition-colors".freeze

  def view_template
    a(href: @back.href, class: "text-sm text-muted hover:text-fg transition-colors") { "← #{@back.label}" }

    header(class: "mt-3 mb-8 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div do
        h1(class: "text-2xl font-semibold tracking-tight") { @document.title }
        p(class: "mt-1 text-sm text-muted") do
          plain(@document.content_type.to_s)
          plain(" · via #{@document.source.name}") if @document.source
        end
      end
      div(class: "flex shrink-0 items-center gap-2") do
        download_button
        reprocess_button if may?(:operator) && @document.reprocessable?
      end
    end

    # Subscribe to the document's stream; the model broadcasts a replace of the
    # Detail region as status advances (pending → processing → processed).
    turbo_stream_from(@document)
    render Views::Documents::Detail.new(document: @document)

    diagnostics if may?(:operator)
  end

  private

  # What went wrong, for the person whose job it is to do something about it.
  # Behind the same role the controller enforces on `reprocess` — hiding a
  # control isn't access control, but showing one that bounces you is just a
  # worse control.
  #
  # The second subscription is what keeps the raw error off everyone else's
  # page: the stream name is only ever rendered here, and Turbo signs it.
  def diagnostics
    turbo_stream_from(@document, :diagnostics)
    render Views::Documents::Diagnostics.new(document: @document)
  end

  def download_button
    render Views::Documents::Access.new(document: @document, class_name: ACCESS)
  end

  # Rendered here rather than inside the broadcast region because it needs a
  # request: a route helper and a CSRF token, neither of which exists when the
  # model renders a region from inside a job. It can afford to be static —
  # `reprocessable?` doesn't change as the pipeline runs.
  def reprocess_button
    form(action: reprocess_document_path(@document), method: "post") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: reprocess_class) { "Reprocess" }
    end
  end

  def reprocess_class
    weight = if @document.failed?
      "bg-accent text-void hover:bg-accent-dim"
    else
      "border border-line text-muted hover:text-fg hover:border-line-2"
    end

    "rounded px-3 py-1.5 text-sm font-medium transition-colors #{weight}"
  end

  def page_title = @document.title
end
