# frozen_string_literal: true

# Who may use one collection or one source, and how much. Shared by both,
# because the two screens are the same screen: what each grant means differs
# and so do the paths, but the rules being expressed — a grant per person,
# capped by their account role — are identical, and drifting apart is exactly
# what you don't want on a page that hands out access.
#
# `member_path` is a lambda rather than a derived route helper because the
# member routes are named `person` under two different parents.
class Views::People::Panel < Components::Base
  COPY = {
    user: { empty: "Nobody has been given access yet.", add: "Give someone access", label: "Person", choose: "Choose someone…" },
    group: { empty: "No group has been given access yet.", add: "Give a group access", label: "Group", choose: "Choose a group…" }
  }.freeze

  def initialize(subject:, grants:, candidates:, access:, create_path:, member_path:, grantee: :user)
    @subject = subject
    @grants = grants
    @candidates = candidates
    @access = access
    @create_path = create_path
    @member_path = member_path
    @grantee = grantee
  end

  def view_template
    @grants.any? ? grants_list : empty_state
    add_form if @candidates.any?
  end

  private

  def copy = COPY.fetch(@grantee)

  def name_of(grantee) = @grantee == :group ? grantee.name : grantee.email_address

  def grants_list
    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      @grants.each { |grant| row(grant) }
    end
  end

  def row(grant)
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0") do
        grantee_name(grant.public_send(@grantee))
        p(class: "mt-0.5 text-xs text-faint") { @grantee == :group ? group_note(grant) : capped_note(grant) }
      end
      div(class: "flex shrink-0 items-center gap-3") do
        access_form(grant)
        revoke(grant)
      end
    end
  end

  def grantee_name(grantee)
    if @grantee == :group && may?(:admin)
      a(href: settings_group_path(grantee), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") do
        grantee.name
      end
    else
      p(class: "truncate text-sm font-medium text-fg") { name_of(grantee) }
    end
  end

  # The ceiling is invisible otherwise: a grant to someone whose account can't
  # use it reads as a mistake until you know it simply doesn't apply.
  def capped_note(grant)
    effective = grant.user.grant_on(@subject)

    if effective.to_s == grant.access
      "#{grant.access.capitalize} here"
    else
      "#{grant.access.capitalize} here, but their account is #{grant.user.role} — so: #{effective || 'no access'}"
    end
  end

  def group_note(grant)
    count = grant.group.group_users.size
    "#{grant.access.capitalize} here for its #{count} #{'member'.pluralize(count)}, each capped by their account role"
  end

  def access_form(grant)
    form(action: @member_path.call(grant), method: "post", class: "flex items-center gap-2") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      select(name: "access", class: select_classes) do
        @access.each_key { |level| option(value: level, selected: grant.access == level) { level.capitalize } }
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
      p(class: "text-sm text-muted") { copy[:empty] }
      p(class: "mt-1 text-xs text-faint") { "Administrators reach everything without a grant." } if @grantee == :user
    end
  end

  def add_form
    h2(class: "mt-8 mb-3 text-sm font-medium text-fg") { copy[:add] }

    form(action: @create_path, method: "post", class: "flex flex-wrap items-end gap-3 rounded-lg border border-line bg-ink/40 p-5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      div(class: "flex-1 basis-48 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "#{@grantee}_grantee") { copy[:label] }
        # Placeholder first, and required: a select that defaults to whoever
        # sorts first will eventually grant access to whoever sorts first.
        select(id: "#{@grantee}_grantee", name: "#{@grantee}_id", required: true, class: "w-full #{select_classes}") do
          option(value: "", disabled: true, selected: true) { copy[:choose] }
          @candidates.each { |candidate| option(value: candidate.id) { name_of(candidate) } }
        end
      end

      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "#{@grantee}_access") { "Access" }
        select(id: "#{@grantee}_access", name: "access", class: "w-full #{select_classes}") do
          @access.each { |level, description| option(value: level) { "#{level.capitalize} — #{description}" } }
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
