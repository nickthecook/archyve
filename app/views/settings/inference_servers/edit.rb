# frozen_string_literal: true

class Views::Settings::InferenceServers::Edit < Views::Base
  def initialize(server:)
    @server = server
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Inference", settings_inference_servers_path],
      [@server.name, settings_inference_server_path(@server)],
      "Edit"
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { @server.name }
      p(class: "mt-1 text-sm text-muted") { "Where this server is, and how to authenticate to it." }
    end

    render Views::Settings::InferenceServers::Form.new(server: @server)
  end

  private

  def page_title = @server.name
end
