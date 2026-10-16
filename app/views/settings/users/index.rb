# frozen_string_literal: true

# Everyone with an account. The only place accounts are created, since Archyve
# has no public sign-up.
class Views::Settings::Users::Index < Views::Base
  def initialize(users:)
    @users = users
  end

  def view_template
    breadcrumb(["Settings", settings_path], "People")

    header(class: "mb-7 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div do
        h1(class: "text-2xl font-semibold tracking-tight") { "People" }
        p(class: "mt-1 text-sm text-muted") { "Who can sign in, and how much of Archyve they see." }
      end
      a(
        href: new_settings_user_path,
        class: button_class(:solid, "shrink-0")
      ) { "Add someone" }
    end

    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      @users.each { |user| row(user) }
    end
  end

  private

  def page_title = "People"

  def row(user)
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0") do
        a(
          href: edit_settings_user_path(user),
          class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors"
        ) { user.email_address }
        p(class: "mt-0.5 text-xs text-faint") { "#{user.role.capitalize} · added #{time_ago_in_words(user.created_at)} ago" }
      end
      div(class: "flex shrink-0 items-center gap-3") do
        you if user == Current.user
        remove(user)
      end
    end
  end

  def you
    span(class: "text-xs text-faint") { "you" }
  end

  def remove(user)
    form(action: settings_user_path(user), method: "post", class: "inline") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "text-xs text-faint hover:text-red-300 transition-colors"
      ) { "Remove" }
    end
  end
end
