# frozen_string_literal: true

# Any tool without a panel of its own: what it checked, and what came back as
# the model read it.
class Views::Conversations::ToolCall < Components::Base
  def initialize(segment:)
    @segment = segment
  end

  def view_template
    details(class: "group rounded-lg border border-line bg-ink/40", open: false) do
      summary(class: "flex cursor-pointer list-none items-center gap-3 px-4 py-3") do
        tile
        span(class: "min-w-0 flex-1 text-[0.8125rem] text-fg") { headline }
        chevron
      end
      body unless running?
    end
  end

  private

  def running? = @segment.tool_result.nil?

  def headline = running? ? "Checking #{@segment.tool_label}…" : "Checked #{@segment.tool_label}"

  def tile
    span(class: "grid h-7 w-7 shrink-0 place-items-center rounded bg-accent/10 text-accent") do
      running? ? render(Views::Spinner.new(size: 15)) : check_icon
    end
  end

  def body
    pre(class: "max-h-96 overflow-auto whitespace-pre-wrap break-words border-t border-line/60 px-4 py-3 " \
               "font-mono text-xs leading-relaxed text-muted") { @segment.tool_result }
  end

  def check_icon
    svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.circle(cx: "11", cy: "11", r: "6")
      s.path(d: "m20 20-4.5-4.5")
    end
  end

  def chevron
    svg(class: "shrink-0 text-faint transition-transform group-open:rotate-90", width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "m9 6 6 6-6 6")
    end
  end
end
