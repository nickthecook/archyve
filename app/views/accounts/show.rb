# frozen_string_literal: true

# Your own account, as opposed to Views::Settings::Index, which administers
# everyone else's. Thin for now — a password change and a statement of who you
# are — but it is the only page a plain user has to themselves, so preferences
# land here as they arrive.
class Views::Accounts::Show < Views::Base
  def initialize(user:, api_keys: [], new_token: nil)
    @user = user
    @api_keys = api_keys
    @new_token = new_token
  end

  def view_template
    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Account" }
      p(class: "mt-1 text-sm text-muted") { "Your sign-in details, preferences and API keys." }
    end

    identity
    @user.sso? ? managed_elsewhere : password_form
    api_keys
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

  # An SSO account has no password to change, and saying so beats a form that
  # can only fail.
  def managed_elsewhere
    div(class: "rounded-lg border border-line bg-ink/40 px-5 py-4") do
      p(class: "text-sm text-muted") do
        plain "You sign in through SSO, so your password is managed there rather than in Archyve."
      end
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

  def api_keys
    section(class: "mt-10") do
      h2(class: "mb-1 text-sm font-medium text-fg") { "API keys" }
      p(class: "mb-3 text-sm text-muted") do
        plain "Send one as "
        code(class: "font-mono text-xs text-fg") { "Authorization: Bearer <key>" }
        plain " to "
        code(class: "font-mono text-xs text-fg") { "/api/tools" }
        plain ". A key can do everything you can."
      end

      new_token if @new_token
      @api_keys.any? ? key_list : no_keys
      new_key_form
    end
  end

  def new_token
    div(class: "mb-4 rounded-lg border border-accent/30 bg-accent/10 p-5") do
      label(for: "new_api_key", class: "block mb-2 text-sm text-accent") do
        "Copy your new key now. It won’t be shown again."
      end
      input(
        type: "text", id: "new_api_key", value: @new_token, readonly: true,
        class: "w-full rounded border border-line bg-void/60 px-3 py-2 font-mono text-sm text-fg outline-none focus:border-accent"
      )
    end
  end

  def key_list
    ul(class: "mb-4 rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      @api_keys.each { key_row(it) }
    end
  end

  def key_row(api_key)
    li(class: "flex items-center justify-between gap-3 px-5 py-3.5") do
      div(class: "min-w-0") do
        p(class: "truncate text-sm font-medium text-fg") { api_key.name }
        p(class: "mt-0.5 text-xs text-faint") do
          span(class: "font-mono") { "#{api_key.token_prefix}…" }
          plain " · created #{time_ago_in_words(api_key.created_at)} ago · #{last_used(api_key)}"
        end
      end
      delete_key(api_key)
    end
  end

  def last_used(api_key)
    return "never used" if api_key.last_used_at.nil?

    "last used #{time_ago_in_words(api_key.last_used_at)} ago"
  end

  def delete_key(api_key)
    form(
      action: account_api_key_path(api_key), method: "post", class: "shrink-0",
      data: { turbo_confirm: "Delete “#{api_key.name}”? Anything using it will stop working." }
    ) do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Delete" }
    end
  end

  def no_keys
    p(class: "mb-4 rounded-lg border border-dashed border-line px-5 py-4 text-sm text-faint") { "No API keys yet." }
  end

  def new_key_form
    form(action: account_api_keys_path, method: "post", class: "flex flex-col gap-3 sm:flex-row sm:items-end") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      div(class: "flex-1") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "api_key_name") { "New key" }
        input(
          type: "text", id: "api_key_name", name: "name", required: true, placeholder: "What will use it?",
          class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
        )
      end
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Create key" }
    end
  end
end
