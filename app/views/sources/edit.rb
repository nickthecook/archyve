# frozen_string_literal: true

class Views::Sources::Edit < Views::Base
  def initialize(source:, collections:, endpoints: [], catalogue: nil)
    @source = source
    @collections = collections
    @endpoints = endpoints
    @catalogue = catalogue
  end

  def view_template
    breadcrumb(
      ["Collections", collections_path],
      ["Sources", sources_path],
      [@source.name, source_path(@source)],
      "Edit"
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Edit source" }
      p(class: "mt-1 text-sm text-muted") { form_component.edit_blurb }
    end

    render form_component.new(source: @source, collections: @collections, endpoints: @endpoints, catalogue: @catalogue)
  end

  private

  def page_title = "Edit #{@source.name}"
  def form_component = @source.class.form_component
end
