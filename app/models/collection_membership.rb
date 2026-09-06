class CollectionMembership < ApplicationRecord
  # Raised when a user-path transition is asked to touch a connector-owned row.
  # (Invariant that a validation can't express: the resulting record state is
  # legal — a removed connector row — so the guard has to live at the boundary.)
  NotUserEditableError = Class.new(StandardError)

  belongs_to :collection
  belongs_to :document

  # How the document came to be in the collection. See docs/architecture.md and
  # the transition vocabulary below.
  #   connector = a connector currently feeds this pair (machine-owned, not user-editable)
  #   manual    = a human put it here (user-owned)
  enum :source, {
    connector: "connector",  # auto-joined because a connector feeds this collection
    manual: "manual"         # explicitly added by a user
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

  # System path. A connector asserting this membership on sync: create it, or
  # restore+claim a removed row, or upgrade an active manual row to connector.
  def self.feed!(document:, collection:)
    membership = find_or_initialize_by(document:, collection:)
    membership.update!(source: :connector, removed_at: nil)
    membership
  end

  # System path. A connector no longer asserts this membership (stopped feeding
  # the collection, or the doc left the source). Retract connector rows; leave
  # manual rows untouched so a human's curation survives.
  def self.unfeed!(document:, collection:)
    membership = active.connector.find_by(document:, collection:)
    membership&.remove!
    membership
  end

  # User path. Add a document to a collection: create it, or restore a removed
  # row as manual (the only way a connector row is ever "downgraded"). If a
  # connector already asserts an active pair it's already a member — no-op, and
  # crucially never downgraded.
  def self.add(document:, collection:)
    membership = find_or_initialize_by(document:, collection:)
    membership.update!(source: :manual, removed_at: nil) if membership.new_record? || !membership.active?
    membership
  end

  # User path. Remove a document from a collection (tombstone, never destroy).
  # Only manual rows are user-editable; a connector row must be retracted at the
  # connector, so asking to remove one is a programming error.
  def self.remove(document:, collection:)
    membership = active.find_by(document:, collection:)
    return nil unless membership
    raise NotUserEditableError, "connector memberships are retracted at the connector, not removed" if membership.connector?

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

  # A live row may be upgraded (manual -> connector) but never downgraded
  # (connector -> manual). The one legitimate downgrade is restoring a *removed*
  # row as manual, so allow the change when it accompanies a restore.
  def no_live_downgrade
    return unless source_changed?(from: "connector", to: "manual")
    return unless removed_at.nil? && removed_at_was.nil?

    errors.add(:source, "cannot be downgraded from connector to manual while active")
  end
end
