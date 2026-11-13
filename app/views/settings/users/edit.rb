# frozen_string_literal: true

class Views::Settings::Users::Edit < Views::Base
  def initialize(user:, collection_grants:, source_grants:, groups:)
    @user = user
    @collection_grants = collection_grants
    @source_grants = source_grants
    @groups = groups
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["People", settings_users_path], @user.email_address)

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { @user.email_address }
      p(class: "mt-1 text-sm text-muted") { "Change their role, or set a new password for them." }
    end

    render Views::Settings::Users::Form.new(user: @user)
    render Views::Settings::Users::Grants.new(
      user: @user,
      collection_grants: @collection_grants,
      source_grants: @source_grants
    )
    groups
  end

  private

def page_title = @user.email_address

def groups
  section(class: "mt-10") do
    h2(class: "mb-3 text-sm font-medium text-fg") { "Groups" }

    if @groups.none?
      div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
        p(class: "text-sm text-muted") { "Not in any group." }
      end
    else
      ul(class: "rounded-lg border border-line bg-ink/40 divide-y divide-line") do
        @groups.each do |group|
          li(class: "px-5 py-4") do
            a(href: settings_group_path(group), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") { group.name }
          end
        end
      end
    end
  end
end
end
