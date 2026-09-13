# frozen_string_literal: true

class Views::Documents::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(document:, back:)
    @document = document
    @back = back
  end

  # Outlined rather than solid: getting a copy *opens* something, it doesn't
  # commit anything — see the accent ladder in docs/design.md. Styled as the
  # page's primary control because on a document there is nothing louder to do.
  ACCESS = "shrink-0 rounded border border-accent/60 bg-accent/10 px-3 py-1.5 text-sm font-medium " \
           "text-accent hover:border-accent hover:bg-accent/20 transition-colors".freeze

  def view_template
    a(href: @back.href, class: "text-sm text-muted hover:text-fg transition-colors") { "← #{@back.label}" }

    header(class: "mt-3 mb-8 flex items-start justify-between gap-4") do
      div do
        h1(class: "text-2xl font-semibold tracking-tight") { @document.title }
        p(class: "mt-1 text-sm text-muted") do
          plain(@document.content_type.to_s)
          plain(" · via #{@document.source.name}") if @document.source
        end
      end
      # A reader who followed a citation here to read the passage often wants
      # the whole thing next. Which affordance this is — a link out to the
      # source, or a download from Archyve — is the source's business, not ours.
      render Views::Documents::Access.new(document: @document, class_name: ACCESS)
    end

    # Subscribe to the document's stream; the model broadcasts a replace of the
    # Detail region as status advances (pending → processing → processed).
    turbo_stream_from(@document)
    render Views::Documents::Detail.new(document: @document)
  end

  private

  def page_title = @document.title
end
