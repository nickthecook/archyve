# What a run did with one item, when that outcome has to outlive the run's
# counters. The counters say three items failed; this says which three and why,
# which is what the UI needs and what `Sources::Sync#tombstone_vanished` needs
# in order not to read "we failed to record it" as "the source no longer has it".
#
# Rows are not a census of what a run saw. See docs/todo.md.
class SourceSyncItem < ApplicationRecord
  belongs_to :source_sync

  # Only the one a scan can produce today. The crawler adds its own in phase 4 of
  # "The web source", where a null disposition additionally means "discovered,
  # not yet attempted".
  enum :disposition, { failed: "failed" }, validate: { allow_nil: true }

  validates :external_id, presence: true
end
