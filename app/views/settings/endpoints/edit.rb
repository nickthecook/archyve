# frozen_string_literal: true

class Views::Settings::Endpoints::Edit < Views::Base
  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Endpoints", settings_endpoints_path],
      [@endpoint.name, settings_endpoint_path(@endpoint)],
      "Edit"
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { @endpoint.name }
      p(class: "mt-1 text-sm text-muted") { "Where this server is, and how to authenticate to it." }
    end

    render @endpoint.class.form_component.new(endpoint: @endpoint)
  end

  private

  def page_title = @endpoint.name
end
