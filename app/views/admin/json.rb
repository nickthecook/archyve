# frozen_string_literal: true

# A jsonb column, folded away until asked for: bodies and header hashes are
# most of what a record like this weighs, and all of it is unreadable at a
# glance.
class Views::Admin::Json < Components::Base
  def initialize(value:)
    @value = value
  end

  def view_template
    return plain(Views::Admin::Formats::BLANK) if @value.blank?

    details(class: "group") do
      summary(class: "cursor-pointer text-xs text-accent hover:text-accent-dim transition-colors") do
        span(class: "group-open:hidden") { "Show" }
        span(class: "hidden group-open:inline") { "Hide" }
      end
      pre(class: "mt-2 max-h-80 overflow-auto whitespace-pre-wrap break-words rounded border border-line " \
                 "bg-void/60 p-3 font-mono text-xs leading-relaxed text-muted") { pretty }
    end
  end

  private

  def pretty
    @value.is_a?(Enumerable) ? JSON.pretty_generate(@value) : @value.to_s
  end
end
