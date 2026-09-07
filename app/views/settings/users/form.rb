# frozen_string_literal: true

# Shared by new and edit. A fragment, so it renders bare inside its page.
class Views::Settings::Users::Form < Components::Base
  def initialize(user:)
    @user = user
  end

  def view_template
    form(action: action, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @user.persisted?
      errors if @user.errors.any?

      field("Email", "How they sign in.") do
        input(
          type: "email", name: "user[email_address]", value: @user.email_address,
          autocomplete: "off", required: true, autofocus: @user.new_record?,
          class: input_classes
        )
      end

      field("Role", role_hint) { role_select }

      field("Password", password_hint) do
        input(
          type: "password", name: "user[password]", autocomplete: "new-password",
          required: @user.new_record?, class: input_classes
        )
      end

      actions
    end
  end

  private

  def action = @user.persisted? ? settings_user_path(@user) : settings_users_path

  def role_hint
    "A ceiling on what they can do anywhere in Archyve."
  end

  def password_hint
    @user.persisted? ? "Leave blank to keep their current password." : "They can change it later under Account."
  end

  def input_classes
    "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
      "outline-none focus:border-accent transition-colors"
  end

  # Described rather than just named — "operator" means nothing on its own, and
  # this is the screen where the choice is actually made.
  ROLE_DESCRIPTIONS = {
    "user" => "Chat and search only",
    "operator" => "…and manage sources, collections and documents",
    "admin" => "…and manage settings and people"
  }.freeze

  def role_select
    select(name: "user[role]", class: input_classes) do
      User.roles.each_key do |role|
        option(value: role, selected: @user.role == role) { "#{role.capitalize} — #{ROLE_DESCRIPTIONS[role]}" }
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

  def errors
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm font-medium text-red-300") { "This account couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @user.errors.full_messages.each { |message| li { message } }
      end
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { @user.persisted? ? "Save" : "Add person" }
      a(href: settings_users_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end
end
