# frozen_string_literal: true

class Views::Sources::Edit < Views::Base
  def initialize(source:, collections:, endpoints: [], catalogue: nil)
    @source = source
    @collections = collections
    @endpoints = endpoints
    @catalogue = catalogue
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: source_path(@source), class: "hover:text-muted transition-colors") { @source.name }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Edit source" }
      p(class: "mt-1 text-sm text-muted") { form_component.edit_blurb }
    end

    render form_component.new(source: @source, collections: @collections, endpoints: @endpoints, catalogue: @catalogue)
  end

  private

  def page_title = "Edit #{@source.name}"
  def form_component = @source.class.form_component
end
