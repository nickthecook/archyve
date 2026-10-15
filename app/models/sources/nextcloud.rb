module Sources
  # Files from a Nextcloud server, reached through an Endpoints::Nextcloud.
  #
  # Shaped like Folder rather than like Bookstack: a WebDAV listing is a
  # directory listing, so the selection is folders and the eligible files are
  # whatever Docling can read. Identity is the path relative to the endpoint's
  # DAV root, so a file that moves reads as a delete plus a create.
  #
  # Nextcloud does hand out an `oc:fileid` that survives a move, which would be
  # the better key — but #read is given only an external_id, and Nextcloud's
  # files endpoint has no GET by file id. The id is kept for the permalink.
  class Nextcloud < Source
    # Nextcloud refuses `Depth: infinity` on PROPFIND, so a tree costs one
    # listing per directory. This caps how many a single scan will make, so a
    # folder picked near the root of a large account fails loudly rather than
    # scanning for hours.
    MAX_DIRECTORIES = 2_000

    # Raised when a scan hits that ceiling. Not a skip: the source is bigger
    # than this source was told to take, and quietly stopping half way would
    # tombstone everything the scan never reached.
    TooManyDirectoriesError = Class.new(StandardError)

    # Folders to sync, relative to the DAV root and without slashes at either
    # end: `["Documents/Handbook", "Policies/2026"]`. What was picked, never its
    # expansion — "sync this folder" has to mean "and whatever lands in it later".
    store_accessor :config, :folders

    # What the picker needs to draw itself: one directory's subdirectories, the
    # directory they are in so it can draw a breadcrumb, and the reason the
    # server couldn't say when it couldn't.
    Catalogue = Data.define(:at, :directories, :error)

    validates :folders, presence: true
    validate :folders_must_be_relative_paths, if: -> { folders.present? }

    def self.endpoint_type = Endpoints::Nextcloud
    def self.supports_sync? = true
    def self.user_creatable? = true
    def self.filters_extensions? = true
    def self.user_accessible_links? = true
    def self.type_label = "Nextcloud"
    def self.form_component = Views::Sources::Forms::Nextcloud

    def self.description
      "Files in folders you pick from a Nextcloud server, including everything in their subfolders. " \
        "Read, never written."
    end

    def location = endpoint&.host

    # Accepts what the picker submits as readily as what is stored, and
    # normalizes both to the one spelling a DAV path has. Unrecognisable entries
    # are kept, not dropped — the validation below is what refuses them, and
    # silently discarding one would turn a typo into a source that syncs less
    # than it was told to.
    def folders=(value)
      super(Array(value).filter_map { |entry| normalize_folder(entry) }.uniq)
    end

    def selected_folders = Array(folders)

    # One directory's subdirectories, or the reason the server couldn't say.
    # Recorded rather than raised, the same way Endpoint#access records it: a
    # server that is down has to render as a sentence, not a 500.
    def catalogue(at: nil)
      here = normalize_folder(at).to_s
      return Catalogue.new(at: here, directories: [], error: nil) if endpoint.blank?

      Catalogue.new(at: here, directories: dav.list(here).select(&:directory?), error: nil)
    rescue StandardError => e
      Rails.logger.error("source #{id} could not list #{endpoint.name}: #{e.class}: #{e.message}")
      Catalogue.new(at: here, directories: [], error: "#{e.class}: #{e.message}")
    end

    # Yields an Item per eligible file under each selected folder.
    #
    # Breadth-first, one listing per directory, because that is what WebDAV
    # offers. Files are yielded as they are found rather than collected, so a
    # deep tree costs one listing's worth of memory; and an external_id is only
    # yielded once however many selected folders contain it.
    def each_item(_run = nil)
      return enum_for(:each_item) unless block_given?

      seen = Set.new
      queue = selected_folders.dup
      listed = 0

      while (directory = queue.shift)
        next unless seen.add?("dir:#{directory}")

        listed += 1
        raise TooManyDirectoriesError, "#{name} spans more than #{MAX_DIRECTORIES} folders" if listed > MAX_DIRECTORIES

        dav.list(directory).each do |entry|
          next queue.push(entry.path) if entry.directory?
          next unless eligible?(entry)
          next unless seen.add?(entry.path)

          yield item_for(entry)
        end
      end
    end

    def read(external_id)
      dav.read(external_id)
    end

    def document_url(document) = document.url

    private

    def dav
      @dav ||= endpoint.dav
    end

    # Strips the slashes a person or a breadcrumb might leave on either end, so
    # `/Documents/` and `Documents` are one folder rather than two.
    def normalize_folder(entry)
      return entry unless entry.is_a?(String)

      cleaned = entry.strip.delete_prefix("/").delete_suffix("/")
      cleaned.presence
    end

    def eligible?(entry)
      EXTRACTABLE_EXTENSIONS.include?(File.extname(entry.name).downcase) && !entry.size.to_i.zero?
    end

    # The version token is the etag alone. Nextcloud moves it when the content
    # changes, which makes it a better token than Folder's size+mtime — but
    # ImportItemJob hashes the bytes either way, so an etag that moved for some
    # other reason costs one fetch rather than a reprocess.
    def item_for(entry)
      Item.new(
        external_id: entry.path,
        version: entry.etag.to_s,
        title: entry.name,
        content_type: entry.content_type.presence || Marcel::MimeType.for(name: entry.name),
        byte_size: entry.size,
        path: directory_of(entry.path),
        url: permalink(entry),
        metadata: { "fileid" => entry.fileid }.compact,
        skip_reason: size_skip_reason(entry.size)
      )
    end

    # Nextcloud's own short link, which survives the file being moved or renamed
    # — unlike a /apps/files URL built from the path.
    def permalink(entry)
      return if entry.fileid.blank?

      "#{endpoint.base_url}/f/#{entry.fileid}"
    end

    # The file's directory, or nil at the top level — File.dirname answers "."
    # there, which is not a breadcrumb.
    def directory_of(path)
      directory = File.dirname(path)
      directory unless directory == "."
    end

    # An oversized file is still *reported*: it is in the folder, we simply won't
    # ingest it. The limit is configurable, and anything missing from a scan gets
    # tombstoned, so omitting these would make lowering the limit delete
    # documents whose files never moved.
    def size_skip_reason(size)
      return if size.to_i <= self.class.max_file_size

      "larger than the #{ActiveSupport::NumberHelper.number_to_human_size(self.class.max_file_size)} limit"
    end

    def folders_must_be_relative_paths
      return if selected_folders.all? { |folder| folder.is_a?(String) && folder.exclude?("..") }

      errors.add(:folders, "must each be a folder path inside the server, with no ..")
    end
  end
end
