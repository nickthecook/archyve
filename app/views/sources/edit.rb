# frozen_string_literal: true

class Views::Sources::Edit < Views::Base
  def initialize(source:, collections:)
    @source = source
    @collections = collections
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: source_path(@source), class: "hover:text-muted transition-colors") { @source.name }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Edit source" }
      p(class: "mt-1 text-sm text-muted") { "Changing the folder re-scans from scratch: documents that aren't under the new path are removed from the archive." }
    end

    render Views::Sources::Form.new(source: @source, collections: @collections)
  end

  private

  def page_title = "Edit #{@source.name}"
end
