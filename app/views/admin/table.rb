# frozen_string_literal: true

# Records in rows, one Views::Admin::Field per column. `href` makes the first
# cell of each row the link into that record.
class Views::Admin::Table < Components::Base
  def initialize(rows:, fields:, href: nil)
    @rows = rows
    @fields = fields
    @href = href
  end

  def view_template
    div(class: "overflow-x-auto rounded-lg border border-line bg-ink/40") do
      table(class: "w-full text-sm") do
        header_row
        tbody(class: "divide-y divide-line") do
          @rows.each { |record| body_row(record) }
        end
      end
    end
  end

  private

  def header_row
    thead(class: "border-b border-line text-xs text-faint") do
      tr do
        @fields.each do |field|
          th(class: "px-4 py-2 font-normal #{field.numeric? ? 'text-right' : 'text-left'}") { field.label }
        end
      end
    end
  end

  def body_row(record)
    tr(class: "hover:bg-ink/60 transition-colors") do
      @fields.each_with_index do |field, index|
        td(class: cell_classes(field)) do
          index.zero? && @href ? linked(record) { emit(field, record) } : emit(field, record)
        end
      end
    end
  end

  def linked(record, &)
    a(href: @href.call(record), class: "block text-fg hover:text-accent transition-colors", &)
  end

  def emit(field, record)
    value = field.value_for(record)
    plain(value) if value.is_a?(String)
  end

  def cell_classes(field)
    [
      "whitespace-nowrap px-4 py-2 text-muted",
      ("text-right" if field.numeric?),
      ("font-mono tabular-nums" if field.mono?)
    ].compact.join(" ")
  end
end
