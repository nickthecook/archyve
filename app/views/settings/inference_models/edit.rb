# frozen_string_literal: true

class Views::Settings::InferenceModels::Edit < Views::Base
  def initialize(server:, model:)
    @server = server
    @model = model
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Inference", settings_inference_servers_path],
      [@server.name, settings_inference_server_path(@server)],
      @model.name
    )

    header(class: "mb-7") do
      h1(class: "font-mono text-2xl font-semibold tracking-tight") { @model.name }
      p(class: "mt-1 text-sm text-muted") { "On #{@server.name}." }
    end

    render Views::Settings::InferenceModels::Form.new(server: @server, model: @model)
  end

  private

  def page_title = @model.name
end
