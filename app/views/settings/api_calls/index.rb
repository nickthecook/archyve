# frozen_string_literal: true

class Views::Settings::ApiCalls::Index < Views::Base
  include Views::Admin::Formats

  def initialize(page:, recording:, facets:, query:)
    @page = page
    @recording = recording
    @facets = facets
    @query = query
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Admin", settings_admin_path], "API calls")
    render Views::Admin::Heading.new(
      title: "API calls",
      blurb: "What Archyve sent inference servers, and what was sent to its API, with what came " \
             "back, while recording was on."
    )

    filters
    @page.any? ? listing : empty
  end

  private

  def page_title = "API calls"
  def filtered? = @query.any?

  # Nothing to narrow, and nothing narrowing: an empty page shouldn't offer
  # controls for the rows it hasn't got.
  def filters
    return unless @page.any? || filtered?

    render Views::Admin::Filters.new(action: settings_api_calls_path, facets: @facets)
  end

  def listing
    render Views::Admin::Table.new(
      rows: @page.records,
      fields:,
      href: ->(call) { settings_api_call_path(call) }
    )
    render Views::Pager.new(page: @page, action: settings_api_calls_path, params: @query)
    sweep_note
  end

  def fields
    [
      Views::Admin::Field.new("When", mono: true) { |call| ago(call.created_at) },
      Views::Admin::Field.new("Direction") { |call| call.incoming? ? "in" : "out" },
      Views::Admin::Field.new("With") { |call| text(call.incoming? ? call.service_name : call.host) },
      Views::Admin::Field.new("Kind") { |call| text(call.kind) },
      Views::Admin::Field.new("Outcome") { |call| render Views::Settings::ApiCalls::Outcome.new(api_call: call) },
      Views::Admin::Field.new("Took", numeric: true) { |call| took(call) }
    ]
  end

  def took(call) = call.duration_ms ? "#{count(call.duration_ms)} ms" : BLANK

  def sweep_note
    p(class: "mt-3 text-xs text-faint") { "Calls are deleted once they are #{ApiCall::RETENTION.inspect} old." }
  end

  def empty
    render Views::Admin::Empty.new(message: empty_message, hint: empty_hint)
  end

  def empty_message
    return "No calls match." if filtered?

    @recording ? "Nothing recorded yet." : "Not recording."
  end

  def empty_hint
    return "Clear the filters to see everything that was recorded." if filtered?
    return "Calls appear here as they're made." if @recording

    "Turn on “Record outgoing API calls” or “Record incoming API calls” below the settings menu " \
      "to start keeping them."
  end
end
