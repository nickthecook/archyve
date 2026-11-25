module Sources
  # Files in folders picked from one document library of a SharePoint site,
  # reached through an Endpoints::Sharepoint.
  #
  # Walks the picked folders rather than reading the library's /delta feed:
  # Sources::Sync wants every item on every scan, and delta's one advantage is
  # reporting only what changed. Identity is Graph's item id, which survives a
  # move or rename, so neither costs a re-ingest.
  class Sharepoint < Source
    MAX_DIRECTORIES = 2_000

    TooManyDirectoriesError = Class.new(StandardError)

    # Folders are paths from the library's root: what was picked, never its
    # expansion, as with Sources::Nextcloud.
    store_accessor :config, :drive_id, :folders

    Catalogue = Data.define(:drives, :drive_id, :at, :directories, :error)

    validates :drive_id, presence: true
    validates :folders, presence: true
    validate :folders_must_be_relative_paths, if: -> { folders.present? }

    def self.endpoint_type = Endpoints::Sharepoint
    def self.supports_sync? = true
    def self.user_creatable? = true
    def self.filters_extensions? = true
    def self.user_accessible_links? = true
    def self.type_label = "SharePoint"
    def self.form_component = Views::Sources::Forms::Sharepoint

    def self.description
      "Files in folders you pick from a SharePoint document library, including everything in their subfolders. " \
        "Read, never written."
    end

    def location = endpoint&.base_url

    def folders=(value)
      super(Array(value).filter_map { |entry| normalize_folder(entry) }.uniq)
    end

    def selected_folders = Array(folders)

    # Lists the chosen library, or the site's first when none is chosen yet, so
    # the picker has folders to show as soon as a server is.
    def catalogue(at: nil)
      here = normalize_folder(at).to_s
      return Catalogue.new(drives: [], drive_id: nil, at: here, directories: [], error: nil) if endpoint.blank?

      drives = graph.drives
      listed = drive_id.presence || drives.first&.id
      directories = listed ? graph.list(listed, here).select(&:directory?) : []

      Catalogue.new(drives:, drive_id: listed, at: here, directories:, error: nil)
    rescue StandardError => e
      Rails.logger.error("source #{id} could not list #{endpoint.name}: #{e.class}: #{e.message}")
      Catalogue.new(drives: drives || [], drive_id: listed, at: here, directories: [], error: "#{e.class}: #{e.message}")
    end

    def each_item(_run = nil)
      return enum_for(:each_item) unless block_given?

      seen = Set.new
      queue = selected_folders.dup
      listed = 0

      while (directory = queue.shift)
        next unless seen.add?("dir:#{directory}")

        listed += 1
        raise TooManyDirectoriesError, "#{name} spans more than #{MAX_DIRECTORIES} folders" if listed > MAX_DIRECTORIES

        graph.list(drive_id, directory).each do |entry|
          next queue.push(entry.path) if entry.directory?
          next unless eligible?(entry)
          next unless seen.add?(entry.id)

          yield item_for(entry)
        end
      end
    end

    def read(external_id) = graph.read(drive_id, external_id)

    def filename_for(document) = document.title

    def document_url(document) = document.url

    private

    def graph
      @graph ||= endpoint.graph
    end

    def normalize_folder(entry)
      return entry unless entry.is_a?(String)

      entry.strip.delete_prefix("/").delete_suffix("/").presence
    end

    def eligible?(entry)
      EXTRACTABLE_EXTENSIONS.include?(File.extname(entry.name).downcase) && !entry.size.to_i.zero?
    end

    def item_for(entry)
      Item.new(
        external_id: entry.id,
        version: entry.version.to_s,
        title: entry.name,
        content_type: Marcel::MimeType.for(name: entry.name),
        byte_size: entry.size,
        path: File.dirname(entry.path).then { |directory| directory unless directory == "." },
        url: entry.web_url,
        metadata: { "modified_at" => entry.modified_at }.compact,
        skip_reason: size_skip_reason(entry.size)
      )
    end

    def folders_must_be_relative_paths
      return if selected_folders.all? { |folder| folder.is_a?(String) && folder.exclude?("..") }

      errors.add(:folders, "must each be a folder path inside the library, with no ..")
    end
  end
end
