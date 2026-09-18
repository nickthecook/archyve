# frozen_string_literal: true

# The status label in a list row. Never-used is grey rather than red: nobody
# having tried yet isn't a fault.
class Views::Settings::Endpoints::AccessState < Components::Base
  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def view_template
    return span(class: "shrink-0 text-xs text-faint") { "never used" } if @endpoint.accessed_at.blank?

    span(class: "shrink-0 inline-flex items-center gap-1.5 text-xs text-muted") do
      span(class: "h-1.5 w-1.5 rounded-full #{@endpoint.accessible? ? 'bg-emerald-400' : 'bg-red-400'}")
      plain(@endpoint.accessible? ? "working" : "failing")
    end
  end
end
