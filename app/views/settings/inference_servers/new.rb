# frozen_string_literal: true

class Views::Settings::InferenceServers::New < Views::Base
  def initialize(server:)
    @server = server
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Inference", settings_inference_servers_path],
      ["Add a server", new_settings_inference_server_path],
      @server.type_label
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Add #{@server.type_label}" }
      p(class: "mt-1 text-sm text-muted") { @server.class.description }
    end

    render Views::Settings::InferenceServers::Form.new(server: @server)
  end

  private

  def page_title = "Add #{@server.type_label}"
end
