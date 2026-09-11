# frozen_string_literal: true

# Shared by new and edit. A fragment, so it renders bare inside its page.
class Views::Settings::InferenceServers::Form < Components::Base
  def initialize(server:)
    @server = server
  end

  def view_template
    form(action: action, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @server.persisted?
      input(type: "hidden", name: "type", value: @server.class.name)

      errors if @server.errors.any?

      field("Name", "A label for this server — how it appears throughout Archyve.") do
        text_input(:name, @server.name, placeholder: "Ollama", autofocus: @server.new_record?)
      end

      field("Address", address_hint) do
        text_input(:base_url, @server.base_url, placeholder: address_placeholder, mono: true)
      end

      field("API key", key_hint) { key_input } if shows_key?

      actions
    end
  end

  private

  def action
    @server.persisted? ? settings_inference_server_path(@server) : settings_inference_servers_path
  end

  def address_hint
    if @server.requires_base_url?
      "Where the server is. The /v1 suffix is optional — Archyve stores the host and adds it where needed."
    else
      "Leave blank for OpenAI itself. Set it to reach anything else that speaks the same API."
    end
  end

  def address_placeholder
    @server.requires_base_url? ? "http://localhost:11434" : "https://api.openai.com/v1"
  end

  # An optional key is still worth offering: an Ollama behind a reverse proxy
  # wants one even though Ollama itself doesn't.
  def shows_key? = true

  def key_hint
    stored = "Stored encrypted. Leave blank to keep the current key."
    required = @server.requires_api_key? ? "Required for #{@server.type_label}. " : "Only needed if the server asks for one. "
    @server.persisted? ? "#{required}#{stored}" : "#{required}Stored encrypted."
  end

  # Never echoes the stored key back into the page. A password field that
  # round-trips a secret puts it in the HTML of every edit screen.
  def key_input
    input(
      type: "password",
      name: "inference_server[api_key]",
      autocomplete: "new-password",
      placeholder: @server.persisted? && @server.api_key.present? ? "unchanged" : nil,
      class: input_classes
    )
  end

  def text_input(name, value, placeholder:, mono: false, autofocus: false)
    input(
      type: "text",
      name: "inference_server[#{name}]",
      value: value,
      placeholder: placeholder,
      autofocus: autofocus,
      autocomplete: "off",
      class: "#{input_classes} #{'font-mono' if mono}"
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
      p(class: "text-sm font-medium text-red-300") { "This server couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @server.errors.full_messages.each { |message| li { message } }
      end
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { @server.persisted? ? "Save" : "Add server" }
      a(href: cancel_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end

  def cancel_path
    @server.persisted? ? settings_inference_server_path(@server) : settings_inference_servers_path
  end
end
