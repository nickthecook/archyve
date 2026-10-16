# One screen of a model's records, and the cursors either side of it.
#
# Cursor paging rather than offset: these lists are written to while they are
# read — a scan files documents, a chat records calls, the sweeper deletes the
# far end — and an offset window shifts under the reader, showing rows twice
# and skipping others. A cursor names a row, so the screen after it is the same
# screen whatever arrived meanwhile.
class Page
  PER_PAGE = 50

  # Newest first suits a log. A list people read by name passes its own
  # ordering — `order: { title: :asc }` — which wants a (title, id) index.
  def self.of(relation, after: nil, before: nil, order: { created_at: :desc }, per: PER_PAGE)
    new(relation, after:, before:, order:, per:)
  end

  def initialize(relation, after:, before:, order:, per:)
    @relation = relation
    @after = after
    @before = before
    @order = order
    @per = per
  end

  def records = page.records
  def any? = records.any?
  def older? = page.has_next?
  def newer? = page.has_previous?
  def older_cursor = page.next_cursor
  def newer_cursor = page.previous_cursor

  private

  # A cursor is a URL anyone can edit, and one that no longer decodes means a
  # stale link rather than a broken page — so it falls back to the newest
  # screen, the same way an unknown filter value is ignored.
  def page
    @page ||= fetch(after: @after, before: @before)
  rescue ActiveRecordCursorPaginate::InvalidCursorError
    @page = fetch
  end

  def fetch(after: nil, before: nil)
    @relation.cursor_paginate(order: @order, limit: @per, after:, before:).fetch
  end
end
