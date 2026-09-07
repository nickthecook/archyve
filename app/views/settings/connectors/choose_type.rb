# frozen_string_literal: true

# Pick what kind of connector to add. A page rather than a button per type: the
# list is driven by Connector.creatable_types, so a new connector type appears here by
# registering itself, and the chrome doesn't grow a button every time.
class Views::Settings::Connectors::ChooseType < Views::Base
  def initialize(types:)
    @types = types
  end

  def view_template
    header(class: "mb-7") do
      div(class: "mb-1 text-xs text-faint") do
        a(href: settings_connectors_path, class: "hover:text-muted transition-colors") { "Connectors" }
      end
      h1(class: "text-2xl font-semibold tracking-tight") { "Add a connector" }
      p(class: "mt-1 text-sm text-muted") { "Choose where the documents will come from." }
    end

    div(class: "flex flex-col gap-3") do
      @types.each { |type| option(type) }
    end
  end

  private

  def page_title = "Add a connector"

  def option(type)
    a(
      href: new_settings_connector_path(type: type.name),
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
