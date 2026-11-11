# frozen_string_literal: true

# Adding or editing one model by hand — the fallback for a provider whose
# discovery can't answer, or a model the endpoint doesn't list.
class Views::Settings::InferenceModels::Form < Components::Base
  def initialize(server:, model:, embedding_locked: false)
    @server = server
    @model = model
    @embedding_locked = embedding_locked
  end

  def view_template
    form(action: action, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @model.persisted?

      errors if @model.errors.any?

      field("Model id", "Exactly as the provider spells it — it's sent verbatim.") do
        text_input(:name, @model.name, placeholder: "llama3.1:8b", mono: true, autofocus: @model.new_record?)
      end

      field("Label", "Optional. Shown instead of the id where a friendlier name helps.") do
        text_input(:display_name, @model.display_name, placeholder: "Llama 3.1")
      end

      kind_field

      field("Context window", "Optional. Tokens the model can take at once.") do
        number_input(:context_window, @model.context_window, placeholder: "8192")
      end

      protocol_field unless @model.persisted? && @model.embedding?

      checkbox_field(
        :supports_tools, "Can call tools",
        "Archyve gives the model retrieval as a tool rather than stuffing documents into the prompt, " \
        "so a chat model without this can't draw on the archive."
      )

      checkbox_field(:enabled, "Available for use", "Uncheck to keep the model without offering it.")

      actions
    end
  end

  private

  def action
    if @model.persisted?
      settings_inference_server_model_path(@server, @model)
    else
      settings_inference_server_models_path(@server)
    end
  end

  # Kind is fixed after creation: a chat model that became an embedding model
  # would strand nothing, but the reverse would orphan every vector that names
  # it. Changing it means deleting and re-adding, which is a decision worth
  # making deliberately. The controller drops the parameter too.
  def kind_field
    if @model.persisted?
      field("Kind", "Fixed once the model exists — remove it and add it again to change this.") do
        p(class: "rounded border border-line bg-void/40 px-3 py-2 font-mono text-sm text-muted") { @model.kind }
      end
    else
      field("Kind", kind_hint) { kind_select }
    end
  end

  def kind_hint
    if @embedding_locked
      "The archive is already embedded, so only a chat model can be added."
    else
      "Embedding models turn text into vectors; chat models answer. Archyve uses exactly one embedder."
    end
  end

  def kind_select
    select(name: "inference_model[kind]", class: input_classes) do
      option(value: "chat", selected: @model.chat?) { "Chat" }
      option(value: "embedding", selected: @model.embedding?, disabled: @embedding_locked) { "Embedding" }
    end
  end

  def protocol_field
    hint = "Chat models only. gpt-5.4 and later, and gpt-6, need Responses to call tools; " \
           "everything else, including vLLM and Ollama, speaks Chat Completions."
    field("API", hint) do
      select(name: "inference_model[protocol]", class: input_classes) do
        option(value: "", selected: @model.protocol.blank?) { "Decide from the model id" } if @model.new_record?
        InferenceModel::PROTOCOLS.each do |value, label|
          option(value:, selected: @model.protocol == value) { label }
        end
      end
    end
  end

  def field(label_text, hint)
    div do
      label(class: "block text-sm font-medium text-fg") { label_text }
      p(class: "mt-0.5 mb-2 text-xs text-faint") { hint }
      yield
    end
  end

  def checkbox_field(name, label_text, hint)
    div do
      label(class: "flex items-start gap-2.5 cursor-pointer") do
        # The empty value means unticking actually submits something; without it
        # a cleared checkbox simply vanishes from the params and nothing changes.
        input(type: "hidden", name: "inference_model[#{name}]", value: "")
        input(
          type: "checkbox", name: "inference_model[#{name}]", value: "1",
          checked: @model.public_send(name), class: "mt-0.5 accent-accent"
        )
        div do
          span(class: "text-sm font-medium text-fg") { label_text }
          p(class: "mt-0.5 text-xs text-faint") { hint }
        end
      end
    end
  end

  def text_input(name, value, placeholder:, mono: false, autofocus: false)
    input(
      type: "text", name: "inference_model[#{name}]", value: value, placeholder: placeholder,
      autofocus: autofocus, autocomplete: "off", class: "#{input_classes} #{'font-mono' if mono}"
    )
  end

  def number_input(name, value, placeholder:)
    input(
      type: "number", name: "inference_model[#{name}]", value: value, placeholder: placeholder,
      min: "1", class: input_classes
    )
  end

  def input_classes
    "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
      "outline-none focus:border-accent transition-colors"
  end

  def errors
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm font-medium text-red-300") { "This model couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @model.errors.full_messages.each { |message| li { message } }
      end
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { @model.persisted? ? "Save" : "Add model" }
      a(
        href: settings_inference_server_path(@server),
        class: "text-sm text-muted hover:text-fg transition-colors"
      ) { "Cancel" }
    end
  end
end
