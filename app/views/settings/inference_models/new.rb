# frozen_string_literal: true

class Views::Settings::InferenceModels::New < Views::Base
  def initialize(server:, model:, embedding_locked:)
    @server = server
    @model = model
    @embedding_locked = embedding_locked
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Inference", settings_inference_servers_path],
      [@server.name, settings_inference_server_path(@server)],
      "Add a model"
    )

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Add a model" }
      p(class: "mt-1 text-sm text-muted") do
        "For anything #{@server.name} doesn't list, or won't describe. Fetching models fills this in for you."
      end
    end

    render Views::Settings::InferenceModels::Form.new(
      server: @server, model: @model, embedding_locked: @embedding_locked
    )
  end

  private

  def page_title = "Add a model"
end
