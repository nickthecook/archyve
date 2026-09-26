# frozen_string_literal: true

# Pick what kind of server to add. A page rather than a button per provider:
# the list comes from InferenceServer.creatable_types, so a new provider appears
# here by registering itself.
#
# These rows stay cards, not doorways. When the links out *are* the content, an
# accent rail on every row is a rail on none — see docs/design.md.
class Views::Settings::InferenceServers::ChooseType < Views::Base
  def initialize(types:)
    @types = types
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Inference", settings_inference_servers_path], "Add a server")

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Add a server" }
      p(class: "mt-1 text-sm text-muted") { "Choose what Archyve will be talking to." }
    end

    div(class: "flex flex-col gap-3") do
      @types.each { |type| option(type) }
    end
  end

  private

  def page_title = "Add a server"

  def option(type)
    a(
      href: new_settings_inference_server_path(type: type.name),
      class: "flex items-center justify-between gap-4 rounded-lg border border-line bg-ink/40 px-5 py-4 hover:border-line-2 transition-colors"
    ) do
      div do
        p(class: "text-sm font-medium text-fg") { type.type_label }
        p(class: "mt-0.5 text-xs text-faint") { type.description }
      end
      span(class: "shrink-0 text-muted") { "→" }
    end
  end
end
