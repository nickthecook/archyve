# frozen_string_literal: true

class Views::Disclaimer < Components::Base
  def initialize(css:)
    @css = css
  end

  def view_template
    disclaimer = Brand.current.disclaimer
    p(class: @css) { disclaimer } if disclaimer.present?
  end
end
