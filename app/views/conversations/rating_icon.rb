# frozen_string_literal: true

class Views::Conversations::RatingIcon < Components::Base
  PATHS = {
    up: ["M7 10v12", "M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 " \
                     "2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z"],
    down: ["M17 14V2", "M9 18.12 10 14H4.17a2 2 0 0 1-1.92-2.56l2.33-8A2 2 0 0 1 6.5 2H20a2 2 0 0 1 2 2v8a2 2 0 0 1-2 " \
                       "2h-2.76a2 2 0 0 0-1.79 1.11L12 22a3.13 3.13 0 0 1-3-3.88Z"]
  }.freeze

  LABELS = { up: "Good answer", down: "Bad answer" }.freeze

  def initialize(rating)
    @rating = rating.to_sym
  end

  def view_template
    svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.8",
      stroke_linecap: "round", stroke_linejoin: "round", aria_hidden: "true") do |s|
      PATHS.fetch(@rating).each { s.path(d: it) }
    end
  end
end
