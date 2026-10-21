# frozen_string_literal: true

class Views::Settings::ApiKeys::Owner < Components::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def view_template
    span(class: "inline-flex flex-wrap items-center gap-2") do
      span { @api_key.user.email_address }
      dormant if @api_key.owner_dormant?
    end
  end

  private

  def dormant
    span(
      class: "inline-flex items-center rounded-full bg-amber-400/15 px-2.5 py-1 text-xs font-medium text-amber-300",
      title: "Hasn't signed in for #{ApiKey::DORMANT_AFTER.inspect}"
    ) { "not signed in lately" }
  end
end
