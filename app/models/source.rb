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
#   #each_item(run)     yields an Item (below) per thing in the source
#   #read(external_id)  returns that item's bytes
#
# `run` is the SourceSync being reconciled. Most sources ignore it — a folder
# enumerates the same way whoever is asking — but a source whose position lives
# in the database rather than in memory needs it, because the position belongs
# to the run and not to the source. See Sources::Web.
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
  #   path          where the item sits in the source, "/"-joined, no leading slash
  #   url           the item's address in the source, when a browser can follow one
  #   metadata      anything else the source knows, merged into source_metadata
  #   skip_reason   nil when ingestable; set when the source has the item but we
  #                 won't take it (see Sources::Sync, which pointedly does not
  #                 tombstone these)
  #
  # Everything but external_id and version is the source's *description* of the
  # item, and Sources::Sync rewrites those whenever they differ — including for
  # an item whose version hasn't moved. Renaming a Bookstack book has to move
  # every page's path without refetching a single one.
  Item = Data.define(:external_id, :version, :title, :content_type, :byte_size, :path, :url, :metadata,
    :skip_reason) do
    def initialize(external_id:, version:, title: nil, content_type: nil, byte_size: nil, path: nil, url: nil,
      metadata: {}, skip_reason: nil)
      # Stringified because the comparison on the other end is against jsonb
      # read back from Postgres; symbol keys would differ forever and rewrite
      # the row on every scan.
      super(external_id:, version:, title:, content_type:, byte_size:, path:, url:,
        metadata: metadata.deep_stringify_keys, skip_reason:)
    end

    def skipped? = skip_reason.present?
  end

  # Formats Docling can extract. Anything else a source enumerates is passed over
  # silently — a source is allowed to hold things that aren't documents, and
  # reporting every .DS_Store as a problem would be noise.
  #
  # On the base class because it describes *extraction*, not any one way of
  # finding files: a folder on disk and a folder in Nextcloud answer this
  # identically. Narrowing the list needs the same care MAX_FILE_SIZE gets — a
  # file that drops out of the list is not a file that left the source.
  EXTRACTABLE_EXTENSIONS = %w[
    .pdf .docx .pptx .xlsx .html .htm .md .markdown .txt .csv .adoc
  ].freeze

  def self.max_file_size
    ENV.fetch("ARCHYVE_MAX_FILE_SIZE_MB", "100").to_i.megabytes
  end

  # Concrete source types, in the order they should be offered in the UI.
  # Listed explicitly rather than found via `descendants` because Zeitwerk only
  # loads a subclass once something references it — in development that list is
  # empty until the class happens to have been touched.
  TYPES = %w[Sources::Folder Sources::Bookstack Sources::Nextcloud Sources::Web Sources::ManualUpload].freeze

  # Fallback when a source names no interval of its own. On the base class
  # because Source.due_for_sync inlines it into SQL for every type at once.
  DEFAULT_SYNC_INTERVAL_MINUTES = 60

  # Only manual upload is owned by a person — every other type is a shared
  # producer with no owner, so this is optional. Nullified rather than cascaded
  # when the owner is deleted; see the AddUserToSources migration.
  belongs_to :user, optional: true

  # The server this source pulls from, and the credentials for it. Optional, and
  # staying that way: Folder reads a path on the local disk and ManualUpload is
  # fed by a person, so neither has a remote host to name.
  belongs_to :endpoint, optional: true

  has_many :source_users, dependent: :destroy
  has_many :users, through: :source_users

  has_many :source_collections, dependent: :destroy
  has_many :collections, through: :source_collections
  has_many :documents, dependent: :destroy
  has_many :syncs, class_name: "SourceSync", dependent: :destroy
  has_many :reprocesses, class_name: "SourceReprocess", dependent: :destroy


  validates :name, presence: true

  # A source that names an endpoint type takes that type and no other: the
  # config a source holds is meaningless against the wrong kind of server.
  validates :endpoint, presence: true, if: -> { self.class.endpoint_type }
  validate :endpoint_must_match_type, if: -> { endpoint && self.class.endpoint_type }

  # Two jsonb columns, two quite different meanings, and they read identically at
  # the call site — so the rule is worth stating where the accessors are declared:
  #
  #   `config` is what a person set, and a form may submit it.
  #   `state`  is what the *source* learned and keeps across runs. No form may
  #            touch it; it is kept out of the permitted keys in SourcesController,
  #            which spec/models/source_spec.rb holds to.
  #
  # What a single *run* learned belongs to the run, not here. A run can be swept
  # and restarted while `state` survives, so run-scoped data parked here outlives
  # the thing that gave it meaning. See docs/todo.md, "The web source".

  # Whether documents from this source get run through OCR. On the base class
  # because it is a property of *extracting* documents, which every source type
  # does, rather than of any one way of fetching them. OCR is expensive.
  store_accessor :config, :ocr

  # Every syncable type polls on an interval, and Source.due_for_sync reads this
  # key out of `config` in SQL for all of them at once — so it lives here rather
  # than being redeclared identically by each type.
  store_accessor :config, :sync_interval_minutes

  validates :sync_interval_minutes,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    allow_blank: true

  def sync_interval
    (sync_interval_minutes.presence || DEFAULT_SYNC_INTERVAL_MINUTES).to_i.minutes
  end

  # When a scan was last asked for by hand. State rather than config: nobody
  # sets this, the source records that it was asked.
  store_accessor :state, :sync_requested_at

  # How long a request stands before the source page stops expecting a run to
  # appear.
  SYNC_REQUEST_WINDOW = 5.minutes

  def request_sync!
    update!(sync_requested_at: Time.current.iso8601(3))
  end

  # A scan is owed: someone asked for one and none has begun since.
  #
  # The gap this describes is small and entirely ordinary — Sources::Sync
  # creates the SourceSync inside the job, so between the button and the run
  # there is no run to show — but nothing else covers it. The broadcast
  # announcing the run fires within milliseconds of the redirect, long before
  # the page it should reach has subscribed, and Turbo Streams do not replay.
  def sync_requested?
    requested = sync_requested_at&.to_time
    return false if requested.nil? || requested < SYNC_REQUEST_WINDOW.ago

    run = latest_sync

    run.nil? || run.started_at < requested
  end

  # Docling's own default, kept deliberately: turning OCR off by default would
  # silently stop extracting every scanned document in an existing archive, and
  # the failure mode — a document that processes to nothing — looks like a
  # broken file rather than a setting.
  OCR_BY_DEFAULT = true

  # Cast on the way in, so `config` holds a real boolean rather than the "1" or
  # "0" a checkbox submits. jsonb is queried directly often enough — by hand, in
  # a console — that storing a string which is truthy either way is a trap.
  def ocr=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def ocr?
    return false unless supports_ocr?

    chosen = ActiveModel::Type::Boolean.new.cast(ocr)
    chosen.nil? ? OCR_BY_DEFAULT : chosen
  end

  # Everything this person may configure, sync or delete. Ownership counts as a
  # grant: your own upload source is yours without anyone having to say so.
  scope :manageable_by, ->(user) {
    next none unless user.at_least?(:curator)
    next all if user.admin?

    where(id: SourceUser.where(user:, role: [:curator, :admin]).select(:source_id))
      .or(where(user_id: user.id))
  }

  # Everything this person may feed into a collection they administer. Any
  # grant will do, including the weakest: `user` means exactly "you may draw on
  # this", which is the whole point of that role. Deliberately wider than
  # manageable_by — attaching a source is not configuring it, and the person who
  # owns a collection is rarely the person who owns the credentials.
  scope :attachable_by, ->(user) {
    next none unless user.at_least?(:curator)

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
    next none unless user.at_least?(:curator)
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
  # otherwise a curator can't manage the source they just created.
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

  scope :past_its_interval, -> {
    where(
      "last_synced_at IS NULL OR last_synced_at < now() - make_interval(mins => COALESCE((config->>'sync_interval_minutes')::int, ?))",
      DEFAULT_SYNC_INTERVAL_MINUTES
    )
  }

  # Sources holding a scan that stopped on its budget. They are due on the very
  # next tick regardless of interval: the interval governs how often a source is
  # re-examined, not how slowly a scan already underway is allowed to finish.
  # Nothing stamps `last_synced_at` until a scan reaches a terminal state, so
  # these would otherwise be invisible to the clause above until the pass that
  # completed them — which is the pass that never comes.
  scope :mid_paused_scan, -> { where(id: SourceSync.paused.select(:source_id)) }

  # Sources the scheduler should sync now: syncable, not already mid-sync, and
  # either past their interval or holding a paused scan to resume. The
  # not-already-running clause is what keeps a slow sync from piling up blocked
  # duplicates behind it every time the scheduler ticks — the job's
  # `limits_concurrency` would serialize them correctly, but they would still
  # queue up, and a sync that ran an hour late would then run a dozen times.
  scope :due_for_sync, -> {
    where(type: syncable_types)
      .where.not(id: SourceSync.running.select(:source_id))
      .merge(mid_paused_scan.or(past_its_interval))
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

  # Whether this source can stop enumerating part-way and pick up where it left
  # off on the next pass, rather than starting over.
  #
  # Only a source that says yes is given a wall-clock budget by Sources::Sync.
  # Handing one to a source that restarts its enumeration every pass would be
  # worse than useless: a source too slow to enumerate inside the budget would
  # be cut off at the same point forever, never reaching the end and never
  # tombstoning anything.
  #
  # A source that returns true is responsible for its own position. `#each_item`
  # is broken out of when the budget expires, so it persists what it needs to
  # `state` as it goes — see the `config`/`state` split in docs/todo.md.
  def self.resumable_scan? = false

  # The kind of Endpoint this source pulls through, or nil for one that reads
  # something local. Drives both the validation above and the options the
  # endpoint picker offers.
  def self.endpoint_type = nil

  # Whether OCR is a meaningful question for this type. A source that fetches
  # markdown has no images in the document to read text from, so the expensive
  # option would be offered for nothing.
  def self.supports_ocr? = true

  # Whether this type applies EXTRACTABLE_EXTENSIONS and the size limit
  def self.filters_extensions? = false

  # The form fields particular to this type, as Endpoint.form_component does.
  # Named through a constant rather than constantized from the type string.
  def self.form_component
    raise MissingImplementationError, "#{name} must name a form component"
  end

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
  # A type that returns true implements #document_url too.
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

  # Whether absence from this scan may be read as deletion. A Folder or BookStack
  # scan enumerates an index the source itself maintains, so absence is the source
  # saying the item is gone. A crawl only reports what it *reached*.
  #
  # An instance method where its neighbours below are class-level delegators: the
  # answer is about one pass rather than about the type, and a crawler weighs it
  # against per-source settings.
  def authoritative_scan?(_run) = true

  def supports_sync? = self.class.supports_sync?

  def current_reprocess = reprocesses.running.first
  def resumable_scan? = self.class.resumable_scan?
  def supports_ocr? = self.class.supports_ocr?
  def filters_extensions? = self.class.filters_extensions?
  def endpoint_type = self.class.endpoint_type
  def feeds_collections? = self.class.feeds_collections?
  def user_accessible_links? = self.class.user_accessible_links?

  # --- sync contract (see the class comment) ---------------------------------

  def each_item(_run = nil)
    raise MissingImplementationError, "#{self.class.name} must implement #each_item"
  end

  def read(_external_id)
    raise MissingImplementationError, "#{self.class.name} must implement #read"
  end

  # What to call the bytes #read returns. Active Storage keeps it and Docling
  # picks its reader off the extension, so a source whose external_id isn't a
  # filename has to answer this itself.
  def filename_for(document) = File.basename(document.external_id)

  # What this source's form needs from the endpoint to draw its pickers, or nil
  # for a type whose configuration is entirely local. Loaded by the controller,
  # never the view: it is a network call.
  #
  # `at` is where in the source the picker is currently looking, for a type whose
  # catalogue is too big to list in one call. Types that list everything ignore it.
  def catalogue(at: nil) = nil

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

  # Where this source's documents live, for a reader who has to tell two
  # similarly-named sources apart — a filesystem path, a site's host. Nil for a
  # type with nowhere to point (manual upload).
  def location = nil

  private

  def endpoint_must_match_type
    return if endpoint.is_a?(self.class.endpoint_type)

    errors.add(:endpoint, "must be a #{self.class.endpoint_type.type_label} endpoint")
  end
end
