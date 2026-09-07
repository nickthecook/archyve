# frozen_string_literal: true

# Your own account, as opposed to Views::Settings::Index, which administers
# everyone else's. Thin for now — a password change and a statement of who you
# are — but it is the only page a plain user has to themselves, so preferences
# land here as they arrive.
class Views::Accounts::Show < Views::Base
  def initialize(user:)
    @user = user
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Account" }
      p(class: "mt-1 text-sm text-muted") { "Your sign-in details and preferences." }
    end

    identity
    password_form
  end

  private

  def page_title = "Account"

  def identity
    dl(class: "mb-8 rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      row("Email", @user.email_address)
      row("Role", @user.role.capitalize)
    end
  end

  def row(label, value)
    div(class: "flex items-center justify-between px-5 py-3.5") do
      dt(class: "text-sm text-muted") { label }
      dd(class: "font-mono text-sm text-fg") { value }
    end
  end

  def password_form
    h2(class: "mb-3 text-sm font-medium text-fg") { "Change password" }

    form(action: account_path, method: "post", class: "flex flex-col gap-5 rounded-lg border border-line bg-ink/40 p-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")

      field("Current password", :current_password, autocomplete: "current-password")
      field("New password", :password, autocomplete: "new-password")
      field("Confirm new password", :password_confirmation, autocomplete: "new-password")

      div do
        button(
          type: "submit",
          class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
        ) { "Change password" }
      end
    end
  end

  def field(label_text, name, autocomplete:)
    div do
      label(class: "block mb-2 text-sm font-medium text-fg", for: "account_#{name}") { label_text }
      input(
        type: "password",
        id: "account_#{name}",
        name: name.to_s,
        autocomplete: autocomplete,
        required: true,
        class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
      )
    end
  end
end
