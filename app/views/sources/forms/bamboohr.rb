# frozen_string_literal: true

class Views::Sources::Forms::Bamboohr < Views::Sources::Form
  def self.new_heading = "Add BambooHR files"

  def self.new_blurb
    "Archyve reads every file in the categories you pick and keeps the archive matching them."
  end

  def self.edit_blurb
    "Unticking a category doesn't delete anything you filed by hand: its files stop being fed, and the ones only this source put in a collection are retired."
  end

  private

  def type_fields
    field("Categories to sync", "Pick as many as you like. Files added to them later are taken too.") { category_picker }
  end

  def new_server_hint
    "The BambooHR company, and the API key Archyve reads it with. Archyve sees exactly what that key's user sees."
  end

  def server_extras = browse_button

  def browse_button
    button(
      type: "submit",
      formmethod: "get",
      formaction: new_source_path(type: @source.class.name),
      class: button_class(:quiet, "shrink-0")
    ) { "Browse" }
  end

  def category_picker
    return catalogue_error if @catalogue&.error
    return nothing_to_pick if categories.empty?

    input(type: "hidden", name: "source[categories][]", value: "")

    div(class: "flex flex-col divide-y divide-line rounded border border-line bg-void/40") do
      categories.each { |category| row(category) }
    end
  end

  def row(category)
    label(class: "flex cursor-pointer items-center gap-3 px-4 py-2.5 hover:bg-ink/60 transition-colors") do
      input(
        type: "checkbox",
        name: "source[categories][]",
        value: category.id,
        checked: @source.selected_categories.include?(category.id),
        class: "h-3.5 w-3.5 shrink-0 accent-accent"
      )
      span(class: "min-w-0 truncate text-sm text-fg") { category.name }
      span(class: "shrink-0 text-xs text-faint") { file_count(category) }
    end
  end

  def file_count(category) = "#{category.files.size} #{'file'.pluralize(category.files.size)}"

  def catalogue_error
    div(class: "rounded border border-danger/40 bg-danger/5 px-3 py-2.5") do
      p(class: "text-sm text-danger-fg") { "Couldn't read #{@source.endpoint&.name}." }
      p(class: "mt-1 font-mono text-xs text-danger-fg/70") { @catalogue.error }
      p(class: "mt-1.5 text-xs text-faint") { "Check the endpoint's address and API key, then Browse again." }
    end
  end

  def nothing_to_pick
    note do
      p(class: "text-sm text-fg") { "No file categories to pick." }
      p(class: "mt-1 text-xs text-faint") do
        "The API key's user can't see any. That is a permissions question in BambooHR."
      end
    end
  end

  def categories = @catalogue&.categories || []
end
