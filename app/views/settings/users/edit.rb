# frozen_string_literal: true

class Views::Settings::Users::Edit < Views::Base
  def initialize(user:, collection_grants:, source_grants:)
    @user = user
    @collection_grants = collection_grants
    @source_grants = source_grants
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
  end

  private

  def page_title = @user.email_address
end
