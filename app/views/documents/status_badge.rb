# frozen_string_literal: true

# A coloured status pill. Takes the status string (not the document) so it stays
# a pure presentation component, reused in the list, the detail panel, and live
# broadcasts.
class Views::Documents::StatusBadge < Components::Base
  COLORS = {
    "pending" => "bg-line/60 text-muted",
    "processing" => "bg-accent/15 text-accent animate-pulse",
    "processed" => "bg-emerald-500/15 text-emerald-300",
    "failed" => "bg-red-500/15 text-red-300",
    "removed" => "bg-line/40 text-faint"
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
