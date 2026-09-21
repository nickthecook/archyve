# What a run did with one item, when that outcome has to outlive the run's
# counters. The counters say three items failed; this says which three and why,
# which is what the UI needs and what `Sources::Sync#tombstone_vanished` needs
# in order not to read "we failed to record it" as "the source no longer has it".
#
# Rows are not a census of what a run saw. See docs/todo.md.
#
# A source that *discovers* its items writes one row per item, because the row
# is how it remembers the work is done: `Sources::Web`'s frontier is the rows
# with no disposition yet, and draining it is the crawl finishing. That
# completeness is a property of how that source uses the table, not of the table.
class SourceSyncItem < ApplicationRecord
  belongs_to :source_sync

  # A null disposition means discovered, not yet attempted — a pending
  # obligation. Everything else is proof an attempt happened and what came of it.
  #
  #   failed             bookkeeping failed while reconciling the item
  #   ok                 fetched, read, handed to the engine
  #   not_found          the source answered 404 or 410
  #   server_error       the source answered 5xx
  #   timeout            no answer in time
  #   connection_failed  never reached the host
  #   redirected         resolved to another URL rather than to content
  #   robots_excluded    reachable, but we are asked not to
  #   forbidden          the source answered 401 or 403 — not ours to hold
  #   nothing_readable   fetched and parsed to nothing worth keeping
  #   out_of_scope       fetched for its links, but not ours to keep
  enum :disposition, {
    failed: "failed",
    ok: "ok",
    not_found: "not_found",
    server_error: "server_error",
    timeout: "timeout",
    connection_failed: "connection_failed",
    redirected: "redirected",
    robots_excluded: "robots_excluded",
    forbidden: "forbidden",
    nothing_readable: "nothing_readable",
    out_of_scope: "out_of_scope"
  }, validate: { allow_nil: true }

  # Whether the source gave us a definite answer about this item.
  #
  # Archyve stores the view of the source *as Archyve sees it*, so a definite
  # answer is acted on even when it is unwelcome: a 403 means this is not ours
  # to hold any more, and the document goes, exactly as a 404 does. Guessing
  # that the content is "probably still there" would be second-guessing the
  # source, and what the archive would then hold is a view nobody can check.
  #
  # The inverse — a timeout, a refused connection, a 5xx, a bookkeeping error
  # of our own — is not an answer at all, and nothing can be concluded from it.
  # It drives two things, and they are the same judgement asked at two scales:
  #
  #   per run   too many inconclusive rows and `authoritative_scan?` says the
  #             scan never really saw the source, so nothing is tombstoned
  #   per item  an individual inconclusive row is no evidence about that one
  #             item, so it is excluded from tombstoning on its own
  #
  # Both are needed. The first is a ratio, so a handful of unreachable pages on
  # a large site clears it comfortably — and would then destroy exactly those
  # pages' chunks without the second.
  CONCLUSIVE_DISPOSITIONS = %w[
    ok not_found redirected robots_excluded nothing_readable out_of_scope forbidden
  ].freeze

  scope :pending, -> { where(disposition: nil) }
  scope :resolved, -> { where.not(disposition: nil) }
  scope :conclusive, -> { where(disposition: CONCLUSIVE_DISPOSITIONS) }
  scope :inconclusive, -> { resolved.where.not(disposition: CONCLUSIVE_DISPOSITIONS) }

  # Rows a finished run has no further use for. The conclusive ones are already
  # in its histogram, and a terminal run's pending rows describe work that will
  # now never happen. Only the inconclusive survive: "this page has failed every
  # scan for a week" is a question about a document over time.
  scope :spent, -> { where(disposition: CONCLUSIVE_DISPOSITIONS + [nil]) }

  validates :external_id, presence: true

  # Dispositions where the status code *is* the story, so the histogram counts
  # them by number. Everything else is named: a timeout has no code to report,
  # and a page that answered 200 and extracted to nothing would otherwise be
  # filed under "200" — indistinguishable from the pages that worked, which is
  # the one distinction the crawl stats exist to draw.
  CODE_DISPOSITIONS = %w[ok not_found server_error redirected].freeze

  # How the run's items resolved, for the summary `SourceSync#response_stats`
  # keeps once the rows themselves are reaped.
  def self.histogram
    resolved.group(:disposition, :status_code).count.each_with_object(Hash.new(0)) do |((disposition, code), count), stats|
      key = code if CODE_DISPOSITIONS.include?(disposition) && code
      stats[key&.to_s || disposition] += count
    end
  end
end
