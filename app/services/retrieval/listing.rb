# frozen_string_literal: true

module Retrieval
  # What walking the archive found: collections, or a page of one collection's
  # documents.
  #
  # Entries are plain hashes with string keys, not records, because a listing is
  # written to the transcript as jsonb and read back from it — a row that read
  # through to the live collection would quietly rewrite what the model was
  # shown the next time a source renamed something.
  #
  # **Nothing in a listing is citable.** There are no passages here and so no
  # hits, which is the whole difference between this and Reading.
  Listing = Data.define(:kind, :title, :entries, :from, :to, :total, :refusal) do
    def initialize(kind:, title: nil, entries: [], from: 1, to: 0, total: 0, refusal: nil)
      super
    end

    def self.refused(refusal, kind:) = new(kind:, refusal:)

    def refused? = !refusal.nil?
    def empty? = entries.empty?

    # More rows sit past what was returned, so the model can ask again from
    # `to + 1` rather than assuming it has seen the lot.
    def more? = !refused? && to < total

    # Asked for a page that starts past the end — the model's own slip, and the
    # one it can fix. Distinct from a collection that is genuinely empty.
    def overshot? = !refused? && empty? && total.positive?
  end
end
