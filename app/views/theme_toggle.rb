# frozen_string_literal: true

# Cycles the theme: match the device, light, dark. A cookie rather than a user
# setting, so it holds on the sign-in page too; Views::Layout reads it to set
# html[data-theme] before first paint.
class Views::ThemeToggle < Components::Base
  CHOICES = %w[system light dark].freeze

  # Literal strings: Tailwind scans this file as text.
  ICONS = {
    "system" => "group-data-[theme-choice-value=system]:block",
    "light" => "group-data-[theme-choice-value=light]:block",
    "dark" => "group-data-[theme-choice-value=dark]:block"
  }.freeze

  def self.choice(cookies) = CHOICES.include?(cookies[:theme]) ? cookies[:theme] : "system"

  def initialize(classes: nil)
    @classes = classes
  end

  def view_template
    choice = self.class.choice(cookies)

    button(
      type: "button",
      title: "Theme: #{choice}",
      aria_label: "Theme: #{choice}",
      class: "group grid place-items-center transition-colors #{@classes}",
      data: { controller: "theme", action: "theme#cycle", theme_choice_value: choice }
    ) do
      ICONS.each { |name, visible| icon(name, visible) }
    end
  end

  private

  def icon(name, visible)
    svg(
      class: "hidden h-4 w-4 #{visible}", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor",
      stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria_hidden: "true"
    ) { |s| send(:"#{name}_shape", s) }
  end

  def system_shape(s)
    s.rect(x: "2", y: "3", width: "20", height: "14", rx: "2")
    s.path(d: "M8 21h8M12 17v4")
  end

  def light_shape(s)
    s.circle(cx: "12", cy: "12", r: "4")
    s.path(d: "M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41")
  end

  def dark_shape(s)
    s.path(d: "M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z")
  end
end
