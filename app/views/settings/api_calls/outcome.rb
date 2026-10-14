# frozen_string_literal: true

# What came back, or why nothing did — response_code carries both, and this
# reads it the way ApiCall splits it.
class Views::Settings::ApiCalls::Outcome < Components::Base
  TINT = {
    ok: "bg-emerald-500/15 text-emerald-300",
    bad: "bg-red-500/15 text-red-300",
    unknown: "bg-line/40 text-faint"
  }.freeze

  def initialize(api_call:)
    @api_call = api_call
  end

  def view_template
    span(class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{TINT.fetch(tint)}") do
      label
    end
  end

  private

  def label
    return "no outcome" if @api_call.response_code.nil?
    return @api_call.response_code.to_s if @api_call.answered?

    @api_call.failure.to_s.humanize.downcase
  end

  def tint
    return :unknown if @api_call.response_code.nil?
    return :bad unless @api_call.answered?

    @api_call.response_code < 400 ? :ok : :bad
  end
end
