# frozen_string_literal: true

class Views::Settings::Users::Grants < Components::Base
  def initialize(user:, collection_grants:, source_grants:)
    @user = user
    @collection_grants = collection_grants
    @source_grants = source_grants
  end

  def view_template
    section(class: "mt-10") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Grants" }
      p(class: "mb-4 text-sm text-muted") { admin_hint } if @user.admin?

      if @collection_grants.none? && @source_grants.none?
        empty_state
      else
        grants_list("Collections", @collection_grants, :collection)
        grants_list("Sources", @source_grants, :source)
      end
    end
  end

  private

  def admin_hint
    "Revoking an admin's grants has no effect: admins can access everything without any grants. " \
      "To limit their access, demote the admin to curator or visitor first."
  end

  def grants_list(heading, grants, kind)
    return if grants.none?

    h3(class: "mt-6 mb-2 text-xs font-medium uppercase tracking-wider text-faint") { heading }
    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      grants.each { |grant| row(grant, kind) }
    end
  end

  def row(grant, kind)
    subject = grant.public_send(kind)

    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0") do
        a(href: people_path(kind, subject), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") do
          subject.name
        end
        p(class: "mt-0.5 text-xs text-faint") { access_note(grant, subject) }
      end
      revoke(grant, kind)
    end
  end

  def people_path(kind, subject)
    kind == :collection ? collection_people_path(subject) : source_people_path(subject)
  end

  def revoke_path(kind, grant)
    kind == :collection ? settings_user_collection_grant_path(@user, grant) : settings_user_source_grant_path(@user, grant)
  end

  def access_note(grant, subject)
    effective = @user.grant_on(subject)

    if effective.to_s == grant.access
      grant.access.capitalize
    else
      "#{grant.access.capitalize}, but their account is #{@user.role} — so: #{effective || 'no access'}"
    end
  end

  def revoke(grant, kind)
    return span(class: "shrink-0 text-xs text-faint opacity-40", aria_disabled: "true") { "Revoke" } if @user.admin?

    form(action: revoke_path(kind, grant), method: "post", class: "inline shrink-0") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Revoke" }
    end
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
      p(class: "text-sm text-muted") { "No grants on any collection or source." }
    end
  end
end
