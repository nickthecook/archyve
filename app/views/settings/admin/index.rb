# frozen_string_literal: true

# The menu of record pages — one card per model, added as each model gets one.
# The pages themselves are generated; see docs/design.md.
class Views::Settings::Admin::Index < Views::Base
  def initialize(api_call_count:, api_key_count:, recording:)
    @api_call_count = api_call_count
    @api_key_count = api_key_count
    @recording = recording
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Admin")
    render Views::Admin::Heading.new(
      title: "Admin",
      blurb: "What Archyve has stored, model by model."
    )

    div(class: "flex flex-col gap-3") do
      render Views::MenuCard.new(
        href: settings_api_calls_path,
        title: "API calls",
        description: "What Archyve sent inference servers and what its API was sent, with what came back.",
        meta: api_call_meta
      ) { api_call_icon }
      render Views::MenuCard.new(
        href: settings_api_keys_path,
        title: "API keys",
        description: "Who can reach the API, and when each key was last used.",
        meta: "#{@api_key_count} #{'key'.pluralize(@api_key_count)}"
      ) { api_key_icon }
    end
  end

  private

  def page_title = "Admin"

  def api_call_meta
    return "#{@api_call_count} #{'call'.pluralize(@api_call_count)}" if @api_call_count.positive?

    @recording ? "recording" : "not recording"
  end

  def api_key_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.circle(cx: "8", cy: "15", r: "4")
      s.path(d: "M10.8 12.2 20 3m-3 3 3 3m-6 0 2 2")
    end
  end

  def api_call_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.path(d: "M4 9h13l-3.2-3.2")
      s.path(d: "M20 15H7l3.2 3.2")
    end
  end
end
