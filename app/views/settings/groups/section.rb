# frozen_string_literal: true

class Views::Settings::Groups::Section < Components::Base
  def initialize(groups:, group:)
    @groups = groups
    @group = group
  end

  def view_template
    section(class: "mb-10") do
      h2(class: "mb-1 text-sm font-medium text-fg") { "Groups" }
      p(class: "mb-3 text-sm text-muted") { "Members get whatever access their group has been given on collections and sources." }

      groups_list if @groups.any?
      new_form
    end
  end

  private

  def groups_list
    ul(class: "mb-3 rounded-lg border border-line bg-ink/40 divide-y divide-line") do
      @groups.each do |group|
        li(class: "px-5 py-4") do
          a(href: settings_group_path(group), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") do
            group.name
          end
          count = group.group_users.size
          p(class: "mt-0.5 text-xs text-faint") { "#{count} #{'member'.pluralize(count)}" }
        end
      end
    end
  end

  def new_form
    form(action: settings_groups_path, method: "post", class: "flex flex-wrap items-end gap-3 rounded-lg border border-line bg-ink/40 p-5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-sm font-medium text-fg", for: "group_name") { "New group" }
        input(
          id: "group_name", type: "text", name: "group[name]", value: @group.name, required: true, autocomplete: "off",
          class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg outline-none focus:border-accent transition-colors"
        )
        p(class: "mt-2 text-xs text-red-300") { @group.errors.full_messages.to_sentence } if @group.errors.any?
      end

      button(type: "submit", class: button_class(:solid, "shrink-0")) { "Add group" }
    end
  end
end
