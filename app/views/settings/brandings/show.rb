# frozen_string_literal: true

class Views::Settings::Brandings::Show < Views::Base
  def initialize(brand:, error: nil)
    @brand = brand
    @error = error
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Branding")

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Branding" }
      p(class: "mt-1 text-sm text-muted") { "What this instance calls itself, and how it looks to people signing in." }
    end

    form(action: settings_branding_path, method: "post", enctype: "multipart/form-data", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      error if @error

      field("Logo", "Shown in place of the triangle mark. PNG, JPEG or WebP, under 2 MB.") { logo_field }

      field("Name", "Shown beside the logo, exactly as typed. Leave it blank to show the logo alone.") do
        input(type: "text", name: "name", value: @brand.name, autocomplete: "off", class: input_classes)
      end

      placeholder_field("Landing placeholder", "ask_placeholder", @brand.ask_placeholder,
        "brand.ask_placeholder", "Shown in the box on the landing page before anyone types.")
      placeholder_field("Chat placeholder", "chat_placeholder", @brand.chat_placeholder,
        "brand.chat_placeholder", "Shown in the box on Chat before anyone types.")

      actions
    end
  end

  private

  def page_title = "Branding"

  def logo_field
    div(data: { controller: "logo-preview" }) do
      div(class: "mb-3 flex items-center gap-4", hidden: !@brand.logo, data: { logo_preview_target: "frame" }) do
        div(class: "rounded border border-line bg-void/60 p-3") do
          img(
            src: (rails_blob_path(@brand.logo, only_path: true) if @brand.logo), alt: "Logo",
            class: "h-10 w-auto max-w-48 object-contain", data: { logo_preview_target: "image" }
          )
        end
        remove_logo if @brand.logo
      end
      input(
        type: "file", name: "logo", accept: Setting::IMAGE_TYPES.join(","),
        class: Views::Documents::UploadFields::FILE_INPUT,
        data: { logo_preview_target: "input", action: "logo-preview#show" }
      )
    end
  end

  def remove_logo
    label(class: "flex cursor-pointer items-center gap-2 text-sm text-muted") do
      input(type: "checkbox", name: "remove_logo", value: "1", class: "accent-accent", data: { logo_preview_target: "remove" })
      span { "Remove logo" }
    end
  end

  def placeholder_field(label_text, name, value, key, hint)
    default = Setting::DEFINITIONS.fetch(key).default
    field(label_text, "#{hint} Leave it blank for “#{default}”.") do
      input(type: "text", name:, value:, placeholder: default, autocomplete: "off", class: input_classes)
    end
  end

  def field(label_text, hint)
    div do
      label(class: "block text-sm font-medium text-fg") { label_text }
      p(class: "mt-0.5 mb-2 text-xs text-faint") { hint }
      yield
    end
  end

  def error
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm text-red-300") { @error }
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Save" }
      a(href: settings_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end

  def input_classes
    "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
      "outline-none focus:border-accent transition-colors"
  end
end
