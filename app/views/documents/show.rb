# frozen_string_literal: true

class Views::Documents::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(document:)
    @document = document
  end

  def view_template
    a(href: documents_path, class: "text-sm text-muted hover:text-fg transition-colors") { "← All documents" }

    header(class: "mt-3 mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { @document.title }
      p(class: "mt-1 text-sm text-muted") do
        plain(@document.content_type.to_s)
        plain(" · via #{@document.connector.name}") if @document.connector
      end
    end

    # Subscribe to the document's stream; the model broadcasts a replace of the
    # Detail region as status advances (pending → processing → processed).
    turbo_stream_from(@document)
    render Views::Documents::Detail.new(document: @document)
  end

  private

  def page_title = @document.title
end
