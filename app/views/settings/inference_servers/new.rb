# frozen_string_literal: true

class Views::Settings::InferenceServers::New < Views::Base
  def initialize(server:)
    @server = server
  end

  def view_template
    a(href: new_settings_inference_server_path, class: "text-sm text-muted hover:text-fg transition-colors") do
      "← Server type"
    end

    header(class: "mt-3 mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Add #{@server.type_label}" }
      p(class: "mt-1 text-sm text-muted") { @server.class.description }
    end

    render Views::Settings::InferenceServers::Form.new(server: @server)
  end

  private

  def page_title = "Add #{@server.type_label}"
end
