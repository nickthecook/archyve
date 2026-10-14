# frozen_string_literal: true

# Newer and Older, either side of one screen of records. Both carry whatever
# else is in the URL — the filters, so paging doesn't drop them.
class Views::Admin::Pager < Components::Base
  BUTTON = "rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg " \
           "hover:border-line-2 transition-colors".freeze

  def initialize(page:, action:, params: {})
    @page = page
    @action = action
    @params = params
  end

  def view_template
    return unless @page.older? || @page.newer?

    nav(class: "mt-4 flex items-center justify-between gap-3") do
      @page.newer? ? step("← Newer", before: @page.newer_cursor) : span
      @page.older? ? step("Older →", after: @page.older_cursor) : span
    end
  end

  private

  def step(label, **cursor)
    a(href: "#{@action}?#{@params.merge(cursor).to_query}", class: BUTTON) { label }
  end
end
