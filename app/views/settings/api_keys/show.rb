# frozen_string_literal: true

class Views::Settings::ApiKeys::Show < Views::Base
  include Views::Admin::Formats

  def initialize(api_key:)
    @api_key = api_key
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Admin", settings_admin_path],
      ["API keys", settings_api_keys_path],
      @api_key.name
    )
    render Views::Admin::Heading.new(title: @api_key.name)
    render Views::Admin::FieldList.new(record: @api_key, fields:)
    remove
  end

  private

  def page_title = @api_key.name

  def fields
    [
      Views::Admin::Field.new("Owner") { |record| render Views::Settings::ApiKeys::Owner.new(api_key: record) },
      Views::Admin::Field.new("Owner last signed in", mono: true) { |record| ago(record.user.last_signed_in_at) },
      Views::Admin::Field.new("Starts with", mono: true) { |record| "#{record.token_prefix}…" },
      Views::Admin::Field.new("Last used", mono: true) { |record| record.last_used_at ? ago(record.last_used_at) : "never" },
      Views::Admin::Field.new("Created", mono: true) { |record| ago(record.created_at) }
    ]
  end

  def remove
    form(
      action: settings_api_key_path(@api_key),
      method: "post",
      class: "mt-6 flex justify-end",
      data: { turbo_confirm: "Delete “#{@api_key.name}”? Anything using it will stop working." }
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(
        type: "submit",
        class: "rounded border border-red-400/40 px-3 py-2 text-sm font-medium text-red-300 " \
               "hover:bg-red-400/10 transition-colors"
      ) { "Delete" }
    end
  end
end
