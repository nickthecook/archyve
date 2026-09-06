# frozen_string_literal: true

# A coloured status pill. Takes the status string (not the document) so it stays
# a pure presentation component, reused in the list, the detail panel, and live
# broadcasts.
class Views::Documents::StatusBadge < Components::Base
  COLORS = {
    "pending" => "bg-slate-100 text-slate-600",
    "processing" => "bg-amber-100 text-amber-800 animate-pulse",
    "processed" => "bg-green-100 text-green-700",
    "failed" => "bg-red-100 text-red-700",
    "removed" => "bg-slate-200 text-slate-500"
  }.freeze

  def initialize(status:)
    @status = status
  end

  def view_template
    span(class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{COLORS.fetch(@status, COLORS['pending'])}") do
      @status
    end
  end
end
