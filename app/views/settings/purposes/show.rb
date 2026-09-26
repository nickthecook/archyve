# frozen_string_literal: true

class Views::Settings::Purposes::Show < Views::Base
  def initialize(purpose:)
    @purpose = purpose
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Purpose")

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Purpose" }
      p(class: "mt-1 text-sm text-muted") { "What this Archyve is for, and who it's answering." }
    end

    form(action: settings_purpose_path, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")

      div do
        label(class: "block text-sm font-medium text-fg", for: "purpose") { "Instance purpose" }
        p(class: "mt-0.5 mb-2 text-xs text-faint") { guidance }
        textarea(
          id: "purpose", name: "purpose", rows: "5", autofocus: true,
          placeholder: "e.g. Answer questions for my family from our home archive.",
          data: { controller: "autogrow", action: "input->autogrow#resize" },
          class: "w-full resize-none overflow-y-hidden rounded border border-line bg-void/60 px-3 py-2 " \
            "text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
        ) { @purpose }
      end

      div(class: "flex items-center gap-3") do
        button(
          type: "submit",
          class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
        ) { "Save" }
        a(href: settings_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
      end
    end
  end

  private

  def page_title = "Purpose"

  def guidance
    "Appended to the system prompt on every chat, after Archyve's own instructions. Say who's using " \
      "this instance and what they need from it — a sentence or two, not a policy document. It " \
      "shapes tone and framing, not behaviour: citation and search rules are already covered and don't " \
      "need repeating here. Leave it blank to inject nothing."
  end
end
