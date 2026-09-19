# frozen_string_literal: true

class Views::Sources::New < Views::Base
  def initialize(source:, collections:, endpoints: [], catalogue: nil)
    @source = source
    @collections = collections
    @endpoints = endpoints
    @catalogue = catalogue
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: sources_path, class: "hover:text-muted transition-colors") { "Sources" }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { form_component.new_heading }
      p(class: "mt-1 text-sm text-muted") { form_component.new_blurb }
    end

    render form_component.new(source: @source, collections: @collections, endpoints: @endpoints, catalogue: @catalogue)
  end

  private

  def page_title = "Add a source"
  def form_component = @source.class.form_component
end
