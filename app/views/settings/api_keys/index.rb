# frozen_string_literal: true

class Views::Settings::ApiKeys::Index < Views::Base
  include Views::Admin::Formats

  def initialize(page:)
    @page = page
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Admin", settings_admin_path], "API keys")
    render Views::Admin::Heading.new(
      title: "API keys",
      blurb: "Every key, and whose it is. A key never checks back with SSO, so a person who " \
             "lost access keeps it until it's deleted here."
    )

    @page.any? ? listing : empty
  end

  private

  def page_title = "API keys"

  def listing
    render Views::Admin::Table.new(
      rows: @page.records,
      fields:,
      href: ->(record) { settings_api_key_path(record) }
    )
    render Views::Pager.new(page: @page, action: settings_api_keys_path)
  end

  def fields
    [
      Views::Admin::Field.new("Name") { |record| shortened(record.name) },
      Views::Admin::Field.new("Owner") { |record| render Views::Settings::ApiKeys::Owner.new(api_key: record) },
      Views::Admin::Field.new("Last used", mono: true) { |record| record.last_used_at ? ago(record.last_used_at) : "never" },
      Views::Admin::Field.new("Created", mono: true) { |record| ago(record.created_at) }
    ]
  end

  def empty
    render Views::Admin::Empty.new(message: "No API keys yet.")
  end
end
