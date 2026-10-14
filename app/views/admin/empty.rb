# frozen_string_literal: true

class Views::Admin::Empty < Components::Base
  def initialize(message:, hint: nil)
    @message = message
    @hint = hint
  end

  def view_template
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { @message }
      p(class: "mt-1 text-xs text-faint") { @hint } if @hint
    end
  end
end
