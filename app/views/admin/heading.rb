# frozen_string_literal: true

class Views::Admin::Heading < Components::Base
  def initialize(title:, blurb: nil)
    @title = title
    @blurb = blurb
  end

  def view_template
    header(class: "mb-7 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div(class: "min-w-0") do
        h1(class: "text-2xl font-semibold tracking-tight") { @title }
        p(class: "mt-1 text-sm text-muted") { @blurb } if @blurb
      end
      div(class: "flex shrink-0 items-center gap-2") { yield } if block_given?
    end
  end
end
