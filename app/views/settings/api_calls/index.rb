# frozen_string_literal: true

class Views::Settings::ApiCalls::Index < Views::Base
  include Views::Admin::Formats

  def initialize(api_calls:, limit:, recording:)
    @api_calls = api_calls
    @limit = limit
    @recording = recording
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Admin", settings_admin_path], "API calls")
    render Views::Admin::Heading.new(
      title: "API calls",
      blurb: "What Archyve sent an inference server and what came back, while recording was on."
    )

    @api_calls.any? ? listing : empty
  end

  private

  def page_title = "API calls"

  def listing
    render Views::Admin::Table.new(
      rows: @api_calls,
      fields:,
      href: ->(call) { settings_api_call_path(call) }
    )
    sweep_note
  end

  def fields
    [
      Views::Admin::Field.new("When", mono: true) { |call| ago(call.created_at) },
      Views::Admin::Field.new("Service") { |call| text(call.service_name) },
      Views::Admin::Field.new("Kind") { |call| text(call.kind) },
      Views::Admin::Field.new("Outcome") { |call| render Views::Settings::ApiCalls::Outcome.new(api_call: call) },
      Views::Admin::Field.new("Took", numeric: true) { |call| took(call) }
    ]
  end

  def took(call) = call.duration_ms ? "#{count(call.duration_ms)} ms" : BLANK

  def sweep_note
    p(class: "mt-3 text-xs text-faint") do
      "#{shown} Calls are deleted once they are #{ApiCall::RETENTION.inspect} old."
    end
  end

  def shown
    @api_calls.size < @limit ? "" : "Showing the most recent #{@limit}. "
  end

  def empty
    render Views::Admin::Empty.new(message: empty_message, hint: empty_hint)
  end

  def empty_message = @recording ? "Nothing recorded yet." : "Not recording."

  def empty_hint
    return "Calls appear here as they go out." if @recording

    "Turn on “Record API calls” below the settings menu to start keeping them."
  end
end
