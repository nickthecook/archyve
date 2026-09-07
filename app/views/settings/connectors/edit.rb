# frozen_string_literal: true

class Views::Settings::Connectors::Edit < Views::Base
  def initialize(connector:, collections:)
    @connector = connector
    @collections = collections
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: settings_connector_path(@connector), class: "hover:text-muted transition-colors") { @connector.name }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Edit connector" }
      p(class: "mt-1 text-sm text-muted") { "Changing the folder re-scans from scratch: documents that aren't under the new path are removed from the archive." }
    end

    render Views::Settings::Connectors::Form.new(connector: @connector, collections: @collections)
  end

  private

  def page_title = "Edit #{@connector.name}"
end
