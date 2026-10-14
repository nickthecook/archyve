# frozen_string_literal: true

# How record values read on an admin page, in one place so generated pages
# agree about it. Each returns a String, so it can be a Views::Admin::Field
# block on its own.
module Views::Admin::Formats
  BLANK = "—"

  def ago(time) = time ? "#{time_ago_in_words(time)} ago" : BLANK
  def yes_no(flag) = flag ? "yes" : "no"
  def count(number) = number ? number_with_delimiter(number) : BLANK
  def text(value) = value.presence&.to_s || BLANK
  def shortened(value, length: 60) = value.present? ? value.to_s.truncate(length) : BLANK
end
