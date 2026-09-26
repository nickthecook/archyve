# frozen_string_literal: true

class Views::Settings::Endpoints::New < Views::Base
  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Endpoints", settings_endpoints_path],
      ["Add an endpoint", new_settings_endpoint_path],
      @endpoint.type_label
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Add #{@endpoint.type_label}" }
      p(class: "mt-1 text-sm text-muted") { @endpoint.class.description }
    end

    render @endpoint.class.form_component.new(endpoint: @endpoint)
  end

  private

  def page_title = "Add #{@endpoint.type_label}"
end
