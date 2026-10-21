# frozen_string_literal: true

class Views::Settings::ApiCalls::Show < Views::Base
  include Views::Admin::Formats

  def initialize(api_call:)
    @api_call = api_call
  end

  def view_template
    breadcrumb(
      ["Settings", settings_path],
      ["Admin", settings_admin_path],
      ["API calls", settings_api_calls_path],
      title
    )
    render Views::Admin::Heading.new(title:)

    render(Views::Admin::Section.new(title: "The call")) { fields(call_fields) }
    render(Views::Admin::Section.new(title: "Request")) { fields(request_fields) }
    render(Views::Admin::Section.new(title: "Response")) { fields(response_fields) }
  end

  private

  def page_title = title
  def title = "#{@api_call.service_name} #{@api_call.kind} call"

  def fields(fields)
    render Views::Admin::FieldList.new(record: @api_call, fields:)
  end

  def call_fields
    [
      Views::Admin::Field.new("When", mono: true) { |call| ago(call.created_at) },
      Views::Admin::Field.new("Direction") { |call| call.incoming? ? "incoming" : "outgoing" },
      Views::Admin::Field.new("Caller") { |call| text(caller_of(call)) },
      Views::Admin::Field.new("Method") { |call| text(call.http_method) },
      Views::Admin::Field.new("URL", mono: true) { |call| text(call.url) },
      Views::Admin::Field.new("Streamed") { |call| yes_no(call.streamed) },
      Views::Admin::Field.new("Answering") { |call| trace(call) }
    ]
  end

  def request_fields
    [
      Views::Admin::Field.new("Headers") { |call| render Views::Admin::Json.new(value: call.request_headers) },
      Views::Admin::Field.new("Body") { |call| render Views::Admin::Json.new(value: call.request_body) },
      Views::Admin::Field.new("Size", numeric: true) { |call| bytes(call.request_length) }
    ]
  end

  def response_fields
    [
      Views::Admin::Field.new("Outcome") { |call| render Views::Settings::ApiCalls::Outcome.new(api_call: call) },
      Views::Admin::Field.new("Took", numeric: true) { |call| took(call) },
      Views::Admin::Field.new("Error") { |call| text(call.error) },
      Views::Admin::Field.new("Headers") { |call| render Views::Admin::Json.new(value: call.response_headers) },
      Views::Admin::Field.new("Body") { |call| render Views::Admin::Json.new(value: call.response_body) },
      Views::Admin::Field.new("Size", numeric: true) { |call| bytes(call.response_length) }
    ]
  end

  def caller_of(call)
    return unless call.incoming?

    [call.user&.email_address, call.api_key&.name].compact.join(" · ")
  end

  def took(call) = call.duration_ms ? "#{count(call.duration_ms)} ms" : BLANK
  def bytes(length) = length ? "#{count(length)} bytes" : BLANK

  # A recorded chat call is usually answering a turn, and the turn is the reason
  # anyone is reading this.
  def trace(call)
    case call.traceable
    when Message then answered_message(call.traceable)
    when nil then BLANK
    else text(call.traceable_type)
    end
  end

  # Only its author can open a conversation, so anyone else gets the title
  # without a link that would 404 on them.
  def answered_message(message)
    conversation = message.conversation
    return text(conversation.title) unless conversation.user == Current.user

    a(
      href: conversation_path(conversation),
      class: "text-accent hover:text-accent-dim transition-colors"
    ) { conversation.title.presence || "the conversation" }
  end
end
