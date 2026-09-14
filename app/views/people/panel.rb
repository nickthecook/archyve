# frozen_string_literal: true

# Who may use one collection or one source, and how much. Shared by both,
# because the two screens are the same screen: the vocabulary differs (a source
# has no reader role) and so do the paths, but the rules being expressed — a
# grant per person, capped by their account role — are identical, and drifting
# apart is exactly what you don't want on a page that hands out access.
#
# `member_path` is a lambda rather than a derived route helper because the
# member routes are named `person` under two different parents.
class Views::People::Panel < Components::Base
  def initialize(subject:, grants:, candidates:, roles:, create_path:, member_path:)
    @subject = subject
    @grants = grants
    @candidates = candidates
    @roles = roles
    @create_path = create_path
    @member_path = member_path
  end

  def view_template
    @grants.any? ? grants_list : empty_state
    add_form if @candidates.any?
  end

  private

  def grants_list
    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      @grants.each { |grant| row(grant) }
    end
  end

  def row(grant)
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0") do
        p(class: "truncate text-sm font-medium text-fg") { grant.user.email_address }
        p(class: "mt-0.5 text-xs text-faint") { capped_note(grant) }
      end
      div(class: "flex shrink-0 items-center gap-3") do
        role_form(grant)
        revoke(grant)
      end
    end
  end

  # The ceiling is invisible otherwise: a grant to someone whose account can't
  # use it reads as a mistake until you know it simply doesn't apply.
  def capped_note(grant)
    effective = grant.user.role_on(@subject)

    if effective.to_s == grant.role
      "#{grant.role.capitalize} here"
    else
      "#{grant.role.capitalize} here, but their account is #{grant.user.role} — so: #{effective || 'no access'}"
    end
  end

  def role_form(grant)
    form(action: @member_path.call(grant), method: "post", class: "flex items-center gap-2") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      select(name: "role", class: select_classes) do
        @roles.each_key { |role| option(value: role, selected: grant.role == role) { role.capitalize } }
      end
      button(type: "submit", class: "text-xs text-muted hover:text-fg transition-colors") { "Save" }
    end
  end

  def revoke(grant)
    form(action: @member_path.call(grant), method: "post", class: "inline") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Revoke" }
    end
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-10 text-center") do
      p(class: "text-sm text-muted") { "Nobody has been given access yet." }
      p(class: "mt-1 text-xs text-faint") { "Administrators reach everything without a grant." }
    end
  end

  def add_form
    h2(class: "mt-8 mb-3 text-sm font-medium text-fg") { "Give someone access" }

    form(action: @create_path, method: "post", class: "flex flex-wrap items-end gap-3 rounded-lg border border-line bg-ink/40 p-5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      div(class: "flex-1 basis-48 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "person_user_id") { "Person" }
        # Placeholder first, and required: a select that defaults to whoever
        # sorts first will eventually grant access to whoever sorts first.
        select(id: "person_user_id", name: "user_id", required: true, class: "w-full #{select_classes}") do
          option(value: "", disabled: true, selected: true) { "Choose someone…" }
          @candidates.each { |user| option(value: user.id) { user.email_address } }
        end
      end

      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "person_role") { "Access" }
        select(id: "person_role", name: "role", class: "w-full #{select_classes}") do
          @roles.each { |role, description| option(value: role) { "#{role.capitalize} — #{description}" } }
        end
      end

      button(
        type: "submit",
        class: "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { "Give access" }
    end
  end

  def select_classes
    "rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg outline-none focus:border-accent transition-colors"
  end
end
