# frozen_string_literal: true

class Views::Settings::Endpoints::Edit < Views::Base
  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def view_template
    a(href: settings_endpoint_path(@endpoint), class: "text-sm text-muted hover:text-fg transition-colors") do
      "← #{@endpoint.name}"
    end

    header(class: "mt-3 mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { @endpoint.name }
      p(class: "mt-1 text-sm text-muted") { "Where this server is, and how to authenticate to it." }
    end

    render @endpoint.class.form_component.new(endpoint: @endpoint)
  end

  private

  def page_title = @endpoint.name
end
