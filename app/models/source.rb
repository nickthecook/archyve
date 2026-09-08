# STI base class. Concrete sources live in app/models/sources/*.
#
# Note on vocabulary: docs/architecture.md describes two layers, a `Source`
# holding config and a separate stateless "adapter" class driving it. This is
# the one place the build diverges — the STI subclass is both, so there is no
# adapter class and the word is avoided here. See the note in architecture.md.
#
# ## The sync contract
#
# A source that returns true from `.supports_sync?` must implement two
# methods, and Sources::Sync can then sync it with no changes of its own:
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
# StandardError` that Sources::Sync uses to record a failed run — the sync
# would abort without ever writing down why. Ruby core also reserves it for
# something narrower (a method genuinely unavailable on this platform, like
# `fork` on Windows), which isn't what a missing subclass implementation is.
class Source < ApplicationRecord
  # Raised when a source claims to support syncing but hasn't implemented the
  # sync contract above.
  MissingImplementationError = Class.new(StandardError)

  # Raised when a source that files per-document is asked to feed a collection
  # wholesale. See .feeds_collections?.
  CannotFeedCollectionsError = Class.new(StandardError)

  # One thing in a source, as the sync engine sees it. Defined here rather than
  # per source because it *is* the contract: Sources::Sync reads these
  # fields and nothing else, so every source describes its source the same way.
  #
  #   external_id   stable identity within the source; the document key
  #   version       changes when the content does — the whole of change detection
  #   skip_reason   nil when ingestable; set when the source has the item but we
  #                 won't take it (see Sources::Sync, which pointedly does not
  #                 tombstone these)
  Item = Data.define(:external_id, :version, :title, :content_type, :byte_size, :skip_reason) do
    def initialize(external_id:, version:, title: nil, content_type: nil, byte_size: nil, skip_reason: nil)
      super
    end

    def skipped? = skip_reason.present?
  end

  # Concrete source types, in the order they should be offered in the UI.
  # Listed explicitly rather than found via `descendants` because Zeitwerk only
  # loads a subclass once something references it — in development that list is
  # empty until the class happens to have been touched.
  TYPES = %w[Sources::Folder Sources::ManualUpload].freeze

  # Only manual upload is owned by a person — every other type is a shared
  # producer with no owner, so this is optional. Nullified rather than cascaded
  # when the owner is deleted; see the AddUserToSources migration.
  belongs_to :user, optional: true

  has_many :source_users, dependent: :destroy
  has_many :users, through: :source_users

  has_many :source_collections, dependent: :destroy
  has_many :collections, through: :source_collections
  has_many :documents, dependent: :destroy
  has_many :syncs, class_name: "SourceSync", dependent: :destroy

  validates :name, presence: true

  # Everything this person may configure, sync or delete. Ownership counts as a
  # grant: your own upload source is yours without anyone having to say so.
  scope :manageable_by, ->(user) {
    next none unless user.at_least?(:operator)
    next all if user.admin?

    where(id: SourceUser.where(user:, role: [:operator, :admin]).select(:source_id))
      .or(where(user_id: user.id))
  }

  # Everything this person may feed into a collection they administer. Any
  # grant will do, including the weakest: `user` means exactly "you may draw on
  # this", which is the whole point of that role. Deliberately wider than
  # manageable_by — attaching a source is not configuring it, and the person who
  # owns a collection is rarely the person who owns the credentials.
  scope :attachable_by, ->(user) {
    next none unless user.at_least?(:operator)

    grants = if user.admin?
      all
    else
      where(id: SourceUser.where(user:).select(:source_id)).or(where(user_id: user.id))
    end

    grants.where(type: feeding_types)
  }

  # Everything they may hand out authority over. Same shape, narrowed to admin
  # grants — and ownership again, since you administer what you own.
  scope :administrable_by, ->(user) {
    next none unless user.at_least?(:operator)
    next all if user.admin?

    where(id: SourceUser.where(user:, role: :admin).select(:source_id)).or(where(user_id: user.id))
  }

  # The grant, or nil. Same question Collection answers, so User#role_on works
  # against either without knowing which it has.
  #
  # Owning a source implies administering it. That is what keeps a per-user
  # upload source working without a redundant grant row beside the user_id that
  # already says whose it is.
  def granted_role_for(user)
    return "admin" if user_id.present? && user_id == user.id

    source_users.find_by(user:)&.role
  end

  # A source has no grants until it has one, so whoever adds it gets it —
  # otherwise an operator can't manage the source they just created.
  def grant_admin_to!(user)
    source_users.create!(user:, role: :admin)
  end

  # Types that can be polled. Manual upload can't — its documents arrive by
  # someone dropping a file on the page, so there is nothing to scan.
  # Types whose documents can join a collection wholesale.
  def self.feeding_types
    TYPES.select { |type| type.constantize.feeds_collections? }
  end

  def self.syncable_types
    TYPES.select { |type| type.constantize.supports_sync? }
  end

  # Sources the scheduler should sync now: syncable, past their interval, and
  # not already mid-sync. That last clause is what keeps a slow sync from piling
  # up blocked duplicates behind it every time the scheduler ticks — the job's
  # `limits_concurrency` would serialize them correctly, but they would still
  # queue up, and a sync that ran an hour late would then run a dozen times.
  scope :due_for_sync, -> {
    where(type: syncable_types)
      .where.not(id: SourceSync.running.select(:source_id))
      .where(
        "last_synced_at IS NULL OR last_synced_at < now() - make_interval(mins => COALESCE((config->>'sync_interval_minutes')::int, ?))",
        Sources::Folder::DEFAULT_SYNC_INTERVAL_MINUTES
      )
  }

  # Subclasses that can be scanned override this and implement the two methods
  # below. Manual upload doesn't: its documents arrive by someone dropping a file
  # on the page, so there is nothing to scan.
  # Whether a *standing* feed makes sense for this type — every document it
  # produces, now and in future, joining the collections it feeds.
  #
  # Manual upload says no. Its documents are filed one at a time, by a person
  # who picks the collection as they upload; a standing feed would mean every
  # file that person ever uploads silently joins, which is not what "upload this
  # to the handbook" asked for.
  def self.feeds_collections? = true

  def self.supports_sync? = false

  # Whether a person can add one of these from the UI. Manual upload exists as a
  # single implicit source created on first upload, not something you add.
  def self.user_creatable? = false

  # Whether this source can produce a link the *reader's browser* can follow.
  #
  # A folder can't: the documents live at a path on the Archyve host, and nobody
  # reading chat results is sitting at that machine, so a file:// link is
  # useless. Manual upload can't either — Archyve is where the file lives. Both
  # are therefore download-only. A wiki or object store with a web UI can, and
  # should link out rather than hand over a copy: the reader gets the live
  # document, with whatever permissions and history the source keeps.
  #
  # Nothing returns true yet. The first source type that can — Bookstack, S3
  # with a console — implements both this and #document_url, and that is also
  # when documents grow a stored URL to return.
  def self.user_accessible_links? = false

  # This document's address in the source, or nil. Only meaningful when
  # .user_accessible_links? is true.
  def document_url(_document) = nil

  # Shown in the source type picker.
  def self.type_label = name.demodulize.underscore.humanize
  def self.description = ""

  # Types offered when adding a source.
  def self.creatable_types
    TYPES.map(&:constantize).select(&:user_creatable?)
  end

  def supports_sync? = self.class.supports_sync?
  def feeds_collections? = self.class.feeds_collections?
  def user_accessible_links? = self.class.user_accessible_links?

  # --- sync contract (see the class comment) ---------------------------------

  def each_item
    raise MissingImplementationError, "#{self.class.name} must implement #each_item"
  end

  def read(_external_id)
    raise MissingImplementationError, "#{self.class.name} must implement #read"
  end

  # Collections this source feeds — produced documents auto-join these.
  def fed_collections
    collections
  end

  def latest_sync
    syncs.recent.first
  end

  # Change which collections this source feeds, and reconcile the memberships
  # that follow from it. Neither half happens on its own: sync only files
  # documents it actually re-imported, so a newly fed collection would stay empty
  # until every document happened to change, and a collection dropped from the
  # list would keep memberships nothing asserts any more.
  #
  # Only the source's own rows move. `feed!` and `unfeed!` leave a membership
  # a person made exactly where it is.
  def update_fed_collections(new_collections)
    if new_collections.any? && !feeds_collections?
      raise CannotFeedCollectionsError, "#{self.class.name} files documents one at a time; it can't feed a collection"
    end

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
