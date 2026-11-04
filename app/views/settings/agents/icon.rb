# frozen_string_literal: true

class Views::Settings::Agents::Icon < Components::Base
  def view_template
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.rect(x: "4.5", y: "8", width: "15", height: "11", rx: "2")
      s.path(d: "M12 4.5V8")
      s.path(d: "M9.5 13h.01M14.5 13h.01")
    end
  end
end
