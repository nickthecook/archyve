# frozen_string_literal: true

class Views::Settings::Connectors::New < Views::Base
  def initialize(connector:, collections:)
    @connector = connector
    @collections = collections
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: settings_connectors_path, class: "hover:text-muted transition-colors") { "Connectors" }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Add a folder" }
      p(class: "mt-1 text-sm text-muted") { "Archyve scans the folder on an interval and keeps the archive matching what's in it." }
    end

    render Views::Settings::Connectors::Form.new(connector: @connector, collections: @collections)
  end

  private

  def page_title = "Add a connector"
end
