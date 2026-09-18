# frozen_string_literal: true

# Shared by new and edit. Holds the fields every endpoint has; each type
# subclasses this to add its own credentials, and names its subclass through
# `Endpoint.form_component`.
class Views::Settings::Endpoints::Form < Components::Base
  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def view_template
    form(action: action, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @endpoint.persisted?
      input(type: "hidden", name: "type", value: @endpoint.class.name)

      errors if @endpoint.errors.any?

      field("Name", "A label for this server — how operators pick it when creating a source.") do
        text_input(:name, @endpoint.name, placeholder: "Work wiki", autofocus: @endpoint.new_record?)
      end

      field("Address", address_hint) do
        text_input(:base_url, @endpoint.base_url, placeholder: address_placeholder, mono: true)
      end

      credential_fields

      actions
    end
  end

  private

  def credential_fields
    raise Endpoint::MissingImplementationError, "#{self.class.name} must implement #credential_fields"
  end

  def address_hint = "Where the server is."
  def address_placeholder = "https://example.com"

  def action
    @endpoint.persisted? ? settings_endpoint_path(@endpoint) : settings_endpoints_path
  end

  def cancel_path
    @endpoint.persisted? ? settings_endpoint_path(@endpoint) : settings_endpoints_path
  end

  def text_input(name, value, placeholder:, mono: false, autofocus: false)
    input(
      type: "text",
      name: "endpoint[#{name}]",
      value: value,
      placeholder: placeholder,
      autofocus: autofocus,
      autocomplete: "off",
      class: "#{input_classes} #{'font-mono' if mono}"
    )
  end

  # Never echoes a stored secret back into the page. The model treats blank as
  # "unchanged", so an edit form can render it empty and mean it.
  def secret_input(name, stored:)
    input(
      type: "password",
      name: "endpoint[#{name}]",
      autocomplete: "new-password",
      placeholder: stored ? "unchanged" : nil,
      class: input_classes
    )
  end

  def input_classes
    "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
      "outline-none focus:border-accent transition-colors"
  end

  def field(label_text, hint)
    div do
      label(class: "block text-sm font-medium text-fg") { label_text }
      p(class: "mt-0.5 mb-2 text-xs text-faint") { hint }
      yield
    end
  end

  def errors
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm font-medium text-red-300") { "This endpoint couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @endpoint.errors.full_messages.each { |message| li { message } }
      end
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { @endpoint.persisted? ? "Save" : "Add endpoint" }
      a(href: cancel_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end
end
