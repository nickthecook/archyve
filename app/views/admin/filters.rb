# frozen_string_literal: true

# The filter row above an admin table: a select per facet, and a Clear that
# appears once something is filtering.
#
# A GET form, so a filtered list is a URL — shareable, bookmarkable, and what
# the back button already expects.
class Views::Admin::Filters < Components::Base
  SELECT = "rounded border border-line bg-ink/60 px-3 py-2 text-sm text-fg outline-none " \
           "focus:border-accent transition-colors".freeze

  def initialize(action:, facets:)
    @action = action
    @facets = facets.select(&:any?)
  end

  def view_template
    return if @facets.empty?

    form(action: @action, method: "get", class: "mb-4 flex flex-wrap items-center gap-2") do
      @facets.each { |facet| picker(facet) }
      button(
        type: "submit",
        class: button_class(:outlined)
      ) { "Filter" }
      clear_link if @facets.any?(&:selected)
    end
  end

  private

  def picker(facet)
    select(name: facet.param, class: SELECT, aria_label: facet.label) do
      option(value: "", selected: facet.selected.nil?) { facet.blank_label }
      facet.options.each { |choice| choose(facet, choice) }
    end
  end

  def clear_link
    a(
      href: clear_href,
      class: button_class(:quiet)
    ) { "Clear" }
  end

  def clear_href
    blanks = @facets.select(&:defaulted?).to_h { [it.param, ""] }
    blanks.empty? ? @action : "#{@action}?#{blanks.to_query}"
  end

  def choose(facet, choice)
    value, label = Array(choice)
    option(value: value, selected: value == facet.selected) { label || value }
  end
end
