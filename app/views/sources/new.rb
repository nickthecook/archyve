# frozen_string_literal: true

class Views::Sources::New < Views::Base
  def initialize(source:, collections:)
    @source = source
    @collections = collections
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: sources_path, class: "hover:text-muted transition-colors") { "Sources" }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Add a folder" }
      p(class: "mt-1 text-sm text-muted") { "Archyve scans the folder on an interval and keeps the archive matching what's in it." }
    end

    render Views::Sources::Form.new(source: @source, collections: @collections)
  end

  private

  def page_title = "Add a source"
end
