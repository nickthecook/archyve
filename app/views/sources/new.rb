# frozen_string_literal: true

class Views::Sources::New < Views::Base
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
      ["Add a source", new_source_path],
      @source.type_label
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { form_component.new_heading }
      p(class: "mt-1 text-sm text-muted") { form_component.new_blurb }
    end

    render form_component.new(source: @source, collections: @collections, endpoints: @endpoints, catalogue: @catalogue)
  end

  private

  def page_title = "Add a source"
  def form_component = @source.class.form_component
end
