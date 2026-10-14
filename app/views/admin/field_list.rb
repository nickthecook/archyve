# frozen_string_literal: true

# One record, a labelled row per Views::Admin::Field. Stacks on a narrow
# screen; labels take their own column from sm: up.
class Views::Admin::FieldList < Components::Base
  def initialize(record:, fields:)
    @record = record
    @fields = fields
  end

  def view_template
    dl(class: "divide-y divide-line rounded-lg border border-line bg-ink/40") do
      @fields.each { |field| field_row(field) }
    end
  end

  private

  def field_row(field)
    div(class: "grid gap-1 px-5 py-3 sm:grid-cols-[11rem_1fr] sm:gap-4") do
      dt(class: "text-xs text-faint sm:pt-0.5") { field.label }
      dd(class: value_classes(field)) { emit(field) }
    end
  end

  def emit(field)
    value = field.value_for(@record)
    plain(value) if value.is_a?(String)
  end

  def value_classes(field)
    "min-w-0 break-words text-sm text-muted#{' font-mono tabular-nums' if field.mono?}"
  end
end
