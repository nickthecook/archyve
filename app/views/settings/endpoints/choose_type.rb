# frozen_string_literal: true

# Pick what kind of endpoint to add. A page even while there is one type:
# arriving at a BookStack form you never chose is jolting, and a new type
# appears here by registering itself.
class Views::Settings::Endpoints::ChooseType < Views::Base
  def initialize(types:)
    @types = types
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: settings_endpoints_path, class: "hover:text-muted transition-colors") { "Endpoints" }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Add an endpoint" }
      p(class: "mt-1 text-sm text-muted") { "Choose what kind of system Archyve will be pulling from." }
    end

    div(class: "flex flex-col gap-3") do
      @types.each { |type| option(type) }
    end
  end

  private

  def page_title = "Add an endpoint"

  def option(type)
    a(
      href: new_settings_endpoint_path(type: type.name),
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
