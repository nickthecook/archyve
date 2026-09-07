class CollectionMembership < ApplicationRecord
  # Raised when a user-path transition is asked to touch a feed row (one a
  # source owns). (Invariant that a validation can't express: the resulting
  # record state is legal — a removed feed row — so the guard has to live at
  # the boundary.)
  NotUserEditableError = Class.new(StandardError)

  belongs_to :collection
  belongs_to :document

  # How the document came to be in the collection. See docs/architecture.md and
  # the transition vocabulary below.
  #   feed   = a source currently feeds this pair (machine-owned, not user-editable)
  #   manual = a human put it here (user-owned)
  enum :origin, {
    feed: "feed",      # auto-joined because a source feeds this collection
    manual: "manual"   # explicitly added by a user
  }

  scope :active, -> { where(removed_at: nil) }
  scope :removed, -> { where.not(removed_at: nil) }

  # At most one row ever exists per pair; re-adding restores the same row.
  validates :document_id, uniqueness: { scope: :collection_id }
  validate :no_live_downgrade

  # --- transition vocabulary -------------------------------------------------
  # There is one row per (document, collection); every transition find-or-builds
  # that row so callers never juggle create-vs-restore. See the transition table
  # in the specs.

  # System path. A source asserting this membership on sync: create it, or
  # restore+claim a removed row, or upgrade an active manual row to source.
  def self.feed!(document:, collection:)
    membership = find_or_initialize_by(document:, collection:)
    membership.update!(origin: :feed, removed_at: nil)
    membership
  end

  # System path. A source no longer asserts this membership (stopped feeding
  # the collection, or the doc left the source). Retract feed rows; leave
  # manual rows untouched so a human's curation survives.
  def self.unfeed!(document:, collection:)
    membership = active.feed.find_by(document:, collection:)
    membership&.remove!
    membership
  end

  # User path. Add a document to a collection: create it, or restore a removed
  # row as manual (the only way a feed row is ever "downgraded"). If a
  # source already asserts an active pair it's already a member — no-op, and
  # crucially never downgraded.
  def self.add(document:, collection:)
    membership = find_or_initialize_by(document:, collection:)
    membership.update!(origin: :manual, removed_at: nil) if membership.new_record? || !membership.active?
    membership
  end

  # User path. Remove a document from a collection (tombstone, never destroy).
  # Only manual rows are user-editable; a feed row must be retracted at the
  # source, so asking to remove one is a programming error.
  def self.remove(document:, collection:)
    membership = active.find_by(document:, collection:)
    return nil unless membership
    raise NotUserEditableError, "feed memberships are retracted at the source, not removed" if membership.feed?

    membership.remove!
    membership
  end

  # --- primitives ------------------------------------------------------------
  def active?
    removed_at.nil?
  end

  def remove!
    update!(removed_at: Time.current)
  end

  def restore!
    update!(removed_at: nil)
  end

  private

  # A live row may be upgraded (manual -> feed) but never downgraded
  # (feed -> manual). The one legitimate downgrade is restoring a *removed*
  # row as manual, so allow the change when it accompanies a restore.
  def no_live_downgrade
    return unless origin_changed?(from: "feed", to: "manual")
    return unless removed_at.nil? && removed_at_was.nil?

    errors.add(:origin, "cannot be downgraded from feed to manual while active")
  end
end
