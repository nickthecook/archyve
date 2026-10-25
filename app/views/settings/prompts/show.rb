# frozen_string_literal: true

class Views::Settings::Prompts::Show < Views::Base
  def initialize(purpose:)
    @purpose = purpose
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Prompt")

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Prompt" }
      p(class: "mt-1 text-sm text-muted") { "What every chat's system prompt tells the model." }
    end

    form(action: settings_prompt_path, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")

      div do
        label(class: "block text-sm font-medium text-fg", for: "purpose") { Setting.label("chat.instance_purpose") }
        p(class: "mt-0.5 mb-2 text-xs text-faint") { Setting.description("chat.instance_purpose") }
        textarea(
          id: "purpose", name: "purpose", rows: "5", autofocus: true,
          placeholder: "e.g. You are Atlas, answering questions for Acme's support team. Be concise.",
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

  def page_title = "Prompt"
end
