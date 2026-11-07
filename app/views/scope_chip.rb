# frozen_string_literal: true

# What a search or chat will be run against. See "The brass dot means scope" in
# docs/design.md.
class Views::ScopeChip < Components::Base
  def initialize(label:, searching: true, title: nil, css: nil)
    @label = label
    @searching = searching
    @title = title
    @css = css
  end

  def view_template
    span(
      title: @title,
      class: "#{@css} inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted"
    ) do
      span(class: "h-1.5 w-1.5 rounded-full #{@searching ? 'bg-accent' : 'bg-line-2'}")
      plain @label
    end
  end
end
