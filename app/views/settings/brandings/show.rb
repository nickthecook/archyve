# frozen_string_literal: true

class Views::Settings::Brandings::Show < Views::Base
  IMAGE_LIMITS = "PNG, JPEG or WebP, under 2 MB."

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

      field("logo", IMAGE_LIMITS) { image_field("logo", @brand.logo) }

      field("name") do
        input(type: "text", name: "name", value: @brand.name, autocomplete: "off", class: input_classes)
      end

      placeholder_field("ask_placeholder", @brand.ask_placeholder)
      placeholder_field("chat_placeholder", @brand.chat_placeholder)

      field("disclaimer") do
        input(
          type: "text", name: "disclaimer", value: @brand.disclaimer, autocomplete: "off",
          placeholder: "e.g. AI can make mistakes; if something seems off, consult your manager.", class: input_classes
        )
      end

      corridor_field

      field("landing_image", IMAGE_LIMITS) do
        image_field("landing_image", @brand.landing_image)
      end

      actions
    end
  end

  private

  def page_title = "Branding"

  def image_field(name, image)
    div(data: { controller: "image-preview" }) do
      div(class: "mb-3 flex items-center gap-4", hidden: !image, data: { image_preview_target: "frame" }) do
        div(class: "rounded border border-line bg-void/60 p-3") do
          img(
            src: (rails_blob_path(image, only_path: true) if image), alt: "",
            class: "#{name == 'logo' ? 'h-10' : 'h-24'} w-auto max-w-48 object-contain",
            data: { image_preview_target: "image" }
          )
        end
        remove_image(name) if image
      end
      input(
        type: "file", name:, accept: Setting::IMAGE_TYPES.join(","),
        class: Views::Documents::UploadFields::FILE_INPUT,
        data: { image_preview_target: "input", action: "image-preview#show" }
      )
    end
  end

  def remove_image(name)
    label(class: "flex cursor-pointer items-center gap-2 text-sm text-muted") do
      input(type: "checkbox", name: "remove_#{name}", value: "1", class: "accent-accent", data: { image_preview_target: "remove" })
      span { name == "logo" ? "Remove logo" : "Remove image" }
    end
  end

  def corridor_field
    div do
      input(type: "hidden", name: "corridor", value: "0")
      label(class: "flex cursor-pointer items-center gap-2 text-sm font-medium text-fg") do
        input(type: "checkbox", name: "corridor", value: "1", checked: @brand.corridor?, class: "accent-accent")
        span { Setting.label("brand.corridor") }
      end
      p(class: "mt-0.5 text-xs text-faint") { Setting.description("brand.corridor") }
    end
  end

  def placeholder_field(name, value)
    default = Setting.default("brand.#{name}")
    field(name, "Leave it blank for “#{default}”.") do
      input(type: "text", name:, value:, placeholder: default, autocomplete: "off", class: input_classes)
    end
  end

  # `name` is the form field, and the setting's key without its "brand." prefix.
  def field(name, addendum = nil)
    key = "brand.#{name}"
    div do
      label(class: "block text-sm font-medium text-fg") { Setting.label(key) }
      p(class: "mt-0.5 mb-2 text-xs text-faint") { [Setting.description(key), addendum].compact.join(" ") }
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
