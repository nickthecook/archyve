# frozen_string_literal: true

class Views::Admin::Section < Components::Base
  def initialize(title:)
    @title = title
  end

  def view_template
    section(class: "mb-8") do
      h2(class: "mb-3 text-sm font-medium text-fg") { @title }
      yield
    end
  end
end
