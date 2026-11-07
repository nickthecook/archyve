# frozen_string_literal: true

# The last scan in a few words, for a row in a list of sources. The full
# account is Views::Sources::LastScan, which shares its dot colours.
class Views::Sources::SyncStatus < Components::Base
  def self.dot_class(sync)
    return "bg-amber-400" if sync.stalled?

    case sync.status
    when "completed" then "bg-emerald-400"
    when "failed" then "bg-red-400"
    else "bg-accent animate-pulse"
    end
  end

  def initialize(sync:)
    @sync = sync
  end

  def view_template
    span(class: "inline-flex items-center gap-1.5 text-xs text-faint") do
      span(class: "h-1.5 w-1.5 shrink-0 rounded-full #{@sync ? self.class.dot_class(@sync) : 'bg-line-2'}")
      plain label
    end
  end

  private

  def label
    return "never scanned" if @sync.nil?
    return "scan stalled" if @sync.stalled?

    case @sync.status
    when "completed" then "scanned #{ago(@sync.finished_at)}"
    when "failed" then "scan failed #{ago(@sync.finished_at)}"
    else "scanning…"
    end
  end

  def ago(time) = "#{time_ago_in_words(time || @sync.started_at)} ago"
end
