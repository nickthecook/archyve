# frozen_string_literal: true

# The one page with a sidebar — see "Narrow viewports" in docs/design.md.
class Views::Help::Show < Views::Base
  def initialize(page:, contents:)
    @page = page
    @contents = contents
  end

  def page_title = @page.title
  def wide? = true

  def view_template
    div(class: "sm:flex sm:items-start sm:gap-10") do
      aside(class: "hidden sm:sticky sm:top-6 sm:block sm:w-56 sm:shrink-0") { contents } if @contents
      div(class: "min-w-0 flex-1") do
        disclosure if @contents
        article(class: "answer help max-w-3xl leading-relaxed text-muted", data: { controller: "fences" }) do
          raw safe(@page.html)
        end
      end
    end
  end

  private

  def disclosure
    details(class: "mb-6 rounded border border-line sm:hidden") do
      summary(class: "cursor-pointer px-4 py-3 text-sm text-muted") { "Contents · #{@page.title}" }
      div(class: "border-t border-line/60 px-4 py-3") { contents }
    end
  end

  def contents
    nav(class: "help-contents text-sm") { raw safe(@contents.html(current: @page.url)) }
  end
end
