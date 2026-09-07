# STI base class. Concrete sources live in app/models/connectors/*.
#
# Note on vocabulary: docs/architecture.md describes two layers, a `Connector`
# holding config and a separate stateless "adapter" class driving it. This is
# the one place the build diverges — the STI subclass is both, so there is no
# adapter class and the word is avoided here. See the note in architecture.md.
#
# ## The sync contract
#
# A connector that returns true from `.supports_sync?` must implement two
# methods, and Connectors::Sync can then sync it with no changes of its own:
#
#   #each_item          yields an Item (below) per thing in the source
#   #read(external_id)  returns that item's bytes
#
# Both are defined below and raise, rather than being left absent. An abstract
# method that isn't written down is a contract you can only discover by reading
# the engine, and a subclass that forgets one would otherwise fail with a bare
# NoMethodError from deep inside a job.
#
# Not NotImplementedError, though it is the usual choice: it descends from
# ScriptError, not StandardError, so it sails straight through the `rescue
# StandardError` that Connectors::Sync uses to record a failed run — the sync
# would abort without ever writing down why. Ruby core also reserves it for
# something narrower (a method genuinely unavailable on this platform, like
# `fork` on Windows), which isn't what a missing subclass implementation is.
class Connector < ApplicationRecord
  # Raised when a connector claims to support syncing but hasn't implemented the
  # sync contract above.
  MissingImplementationError = Class.new(StandardError)

  # One thing in a source, as the sync engine sees it. Defined here rather than
  # per connector because it *is* the contract: Connectors::Sync reads these
  # fields and nothing else, so every connector describes its source the same way.
  #
  #   external_id   stable identity within the connector; the document key
  #   version       changes when the content does — the whole of change detection
  #   skip_reason   nil when ingestable; set when the source has the item but we
  #                 won't take it (see Connectors::Sync, which pointedly does not
  #                 tombstone these)
  Item = Data.define(:external_id, :version, :title, :content_type, :byte_size, :skip_reason) do
    def initialize(external_id:, version:, title: nil, content_type: nil, byte_size: nil, skip_reason: nil)
      super
    end

    def skipped? = skip_reason.present?
  end

  # Concrete connector types, in the order they should be offered in the UI.
  # Listed explicitly rather than found via `descendants` because Zeitwerk only
  # loads a subclass once something references it — in development that list is
  # empty until the class happens to have been touched.
  TYPES = %w[Connectors::Folder Connectors::ManualUpload].freeze

  has_many :connector_collections, dependent: :destroy
  has_many :collections, through: :connector_collections
  has_many :documents, dependent: :destroy
  has_many :syncs, class_name: "ConnectorSync", dependent: :destroy

  validates :name, presence: true

  # Types that can be polled. Manual upload can't — its documents arrive by
  # someone dropping a file on the page, so there is nothing to scan.
  def self.syncable_types
    TYPES.select { |type| type.constantize.supports_sync? }
  end

  # Connectors the scheduler should sync now: syncable, past their interval, and
  # not already mid-sync. That last clause is what keeps a slow sync from piling
  # up blocked duplicates behind it every time the scheduler ticks — the job's
  # `limits_concurrency` would serialize them correctly, but they would still
  # queue up, and a sync that ran an hour late would then run a dozen times.
  scope :due_for_sync, -> {
    where(type: syncable_types)
      .where.not(id: ConnectorSync.running.select(:connector_id))
      .where(
        "last_synced_at IS NULL OR last_synced_at < now() - make_interval(mins => COALESCE((config->>'sync_interval_minutes')::int, ?))",
        Connectors::Folder::DEFAULT_SYNC_INTERVAL_MINUTES
      )
  }

  # Subclasses that can be scanned override this and implement the two methods
  # below. Manual upload doesn't: its documents arrive by someone dropping a file
  # on the page, so there is nothing to scan.
  def self.supports_sync? = false

  # Whether a person can add one of these from the UI. Manual upload exists as a
  # single implicit connector created on first upload, not something you add.
  def self.user_creatable? = false

  # Shown in the connector type picker.
  def self.type_label = name.demodulize.underscore.humanize
  def self.description = ""

  # Types offered when adding a connector.
  def self.creatable_types
    TYPES.map(&:constantize).select(&:user_creatable?)
  end

  def supports_sync? = self.class.supports_sync?

  # --- sync contract (see the class comment) ---------------------------------

  def each_item
    raise MissingImplementationError, "#{self.class.name} must implement #each_item"
  end

  def read(_external_id)
    raise MissingImplementationError, "#{self.class.name} must implement #read"
  end

  # Collections this connector feeds — produced documents auto-join these.
  def fed_collections
    collections
  end

  def latest_sync
    syncs.recent.first
  end

  # Change which collections this connector feeds, and reconcile the memberships
  # that follow from it. Neither half happens on its own: sync only files
  # documents it actually re-imported, so a newly fed collection would stay empty
  # until every document happened to change, and a collection dropped from the
  # list would keep memberships nothing asserts any more.
  #
  # Only the connector's own rows move. `feed!` and `unfeed!` leave a membership
  # a person made exactly where it is.
  def update_fed_collections(new_collections)
    added = new_collections - collections
    dropped = collections - new_collections

    transaction do
      self.collections = new_collections

      documents.where.not(status: :removed).find_each do |document|
        added.each { |collection| CollectionMembership.feed!(document:, collection:) }
      end

      documents.find_each do |document|
        dropped.each { |collection| CollectionMembership.unfeed!(document:, collection:) }
      end
    end
  end

  # Human label for the type, e.g. "Folder". Used in the UI where showing the
  # STI class name would be noise.
  def type_label = self.class.type_label
end
