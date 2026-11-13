# frozen_string_literal: true

# One group: who is in it, and what it has been given. Its grants are handed out
# from each collection's or source's People page, so they are listed here
# read-only, linking there.
class Views::Settings::Groups::Show < Views::Base
  def initialize(group:, members:, candidates:, collection_grants:, source_grants:)
    @group = group
    @members = members
    @candidates = candidates
    @collection_grants = collection_grants
    @source_grants = source_grants
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["People", settings_users_path], @group.name_was)

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { @group.name_was }
      p(class: "mt-1 text-sm text-muted") { "Members get this group's access, each capped by their own account role." }
    end

    rename_form
    members
    grants
    delete_group
  end

  private

  def page_title = @group.name_was

  def rename_form
    form(action: settings_group_path(@group), method: "post", class: "flex flex-wrap items-end gap-3") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")

      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "group_name") { "Name" }
        input(id: "group_name", type: "text", name: "group[name]", value: @group.name, required: true, class: input_classes)
        p(class: "mt-2 text-xs text-red-300") { @group.errors.full_messages.to_sentence } if @group.errors.any?
      end

      button(type: "submit", class: button_class(:quiet, "shrink-0")) { "Rename" }
    end
  end

  def members
    section(class: "mt-10") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Members" }

      if @members.any?
        ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
          @members.each { |member| member_row(member) }
        end
      else
        div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
          p(class: "text-sm text-muted") { "Nobody is in this group yet." }
        end
      end

      add_member_form if @candidates.any?
    end
  end

  def member_row(member)
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      div(class: "min-w-0") do
        a(href: edit_settings_user_path(member.user), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") do
          member.user.email_address
        end
        p(class: "mt-0.5 text-xs text-faint") { member.user.role.capitalize }
      end
      form(action: settings_group_member_path(@group, member), method: "post", class: "inline shrink-0") do
        input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
        input(type: "hidden", name: "_method", value: "delete")
        button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Remove" }
      end
    end
  end

  def add_member_form
    form(action: settings_group_members_path(@group), method: "post", class: "mt-4 flex flex-wrap items-end gap-3 rounded-lg border border-line bg-ink/40 p-5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "member_user_id") { "Person" }
        select(id: "member_user_id", name: "user_id", required: true, class: input_classes) do
          option(value: "", disabled: true, selected: true) { "Choose someone…" }
          @candidates.each { |user| option(value: user.id) { user.email_address } }
        end
      end

      button(type: "submit", class: button_class(:solid, "shrink-0")) { "Add to group" }
    end
  end

  def grants
    section(class: "mt-10") do
      h2(class: "mb-3 text-sm font-medium text-fg") { "Access" }

      if @collection_grants.none? && @source_grants.none?
        div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
          p(class: "text-sm text-muted") { "This group hasn't been given access to anything." }
          p(class: "mt-1 text-xs text-faint") { "Give it access from a collection's or source's People page." }
        end
      else
        grants_list("Collections", @collection_grants) { |grant| [grant.collection.name, collection_people_path(grant.collection)] }
        grants_list("Sources", @source_grants) { |grant| [grant.source.name, source_people_path(grant.source)] }
      end
    end
  end

  def grants_list(heading, grants)
    return if grants.none?

    h3(class: "mt-6 mb-2 text-xs font-medium uppercase tracking-wider text-faint") { heading }
    ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      grants.each do |grant|
        name, href = yield(grant)
        li(class: "px-5 py-4") do
          a(href:, class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") { name }
          p(class: "mt-0.5 text-xs text-faint") { grant.access.capitalize }
        end
      end
    end
  end

  def delete_group
    div(class: "mt-10 border-t border-line/60 pt-5 flex items-center justify-between gap-4") do
      div do
        p(class: "text-sm text-muted") { "Delete this group" }
        p(class: "mt-0.5 text-xs text-faint") { "Members lose what the group gave them. Their own grants stay." }
      end
      form(
        action: settings_group_path(@group), method: "post", class: "shrink-0",
        data: { turbo_confirm: "Delete “#{@group.name_was}”? Its members lose the access it gave them." }
      ) do
        input(type: "hidden", name: "_method", value: "delete")
        input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
        button(type: "submit", class: button_class(:danger)) { "Delete" }
      end
    end
  end

  def input_classes
    "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg outline-none focus:border-accent transition-colors"
  end
end
