module Sources
  # Syncs a directory on the machine running Archyve. The simplest possible
  # source — no credentials, no pagination, no API — which makes it the one that
  # defines the shape every later source implements: #each_item to enumerate,
  # #fetch to read one item's bytes.
  #
  # Identity is the path relative to the configured root, so a file that moves
  # reads as a delete plus a create. That is the honest reading: nothing about a
  # filesystem lets us recognise a moved file as the same document.
  class Folder < Source
    # Raised when a path escapes the configured root — see #fetch.
    OutsideRootError = Class.new(StandardError)

    # Formats Docling can extract. Anything else in the folder is passed over
    # silently — a source directory is allowed to contain things that aren't
    # documents, and reporting every .DS_Store as a problem would be noise.
    #
    # If these ever become per-source configuration, narrowing the list will
    # need the same treatment MAX_FILE_SIZE gets below: a file that drops out of
    # the list is not a file that left the source.
    EXTENSIONS = %w[
      .pdf .docx .pptx .xlsx .html .htm .md .markdown .txt .csv .adoc
    ].freeze

    def self.max_file_size
      ENV.fetch("ARCHYVE_MAX_FILE_SIZE_MB", "100").to_i.megabytes
    end

    store_accessor :config, :path

    validates :path, presence: true
    validate :path_must_be_an_absolute_directory, if: -> { path.present? }

    def self.supports_sync? = true
    def self.user_creatable? = true
    def self.form_component = Views::Sources::Forms::Folder

    def self.description
      "A directory on the machine running Archyve. Scanned on an interval; read, never written."
    end

    # Yields an Item per eligible file, recursively.
    #
    # The version token is size + mtime rather than a content hash: it is one
    # stat() instead of reading every file on every scan, which is what keeps a
    # large folder cheap to re-scan. It over-reports — `touch` changes mtime
    # without changing content — so Sources::ImportItemJob hashes the bytes
    # it reads and skips re-processing when they match. Cheap check first,
    # honest check only for the files that look changed.
    def each_item(_run = nil)
      return enum_for(:each_item) unless block_given?

      root = Pathname.new(path).cleanpath

      Dir.glob("**/*", base: root.to_s).each do |relative|
        absolute = root.join(relative)

        # Anything hidden, at any depth: `.env`, `.git/config`, `.ssh/id_rsa`.
        # `Dir.glob` already declines to match dot-entries, so this is belt and
        # braces — but "never ingest a dotfile" is a rule worth stating outright
        # rather than leaving to a glob subtlety somebody might later "fix".
        next if hidden?(relative)

        # Symlinks are skipped entirely: following them invites both cycles and
        # reads outside the root the user configured.
        next if File.symlink?(absolute)
        next unless File.file?(absolute)
        next unless EXTENSIONS.include?(File.extname(relative).downcase)

        stat = File.stat(absolute)
        next if stat.size.zero?

        yield Item.new(
          external_id: relative,
          version: "#{stat.size}-#{stat.mtime.to_i}",
          title: File.basename(relative),
          content_type: Marcel::MimeType.for(Pathname.new(absolute), name: relative),
          byte_size: stat.size,
          path: directory_of(relative),
          skip_reason: size_skip_reason(stat.size)
        )
      end
    end

    # Read one item's bytes by external_id.
    #
    # Re-resolves the path against the root and refuses anything that lands
    # outside it. external_id comes back from our own database rather than from
    # a user, but it is the one value in the flow that names a filesystem path,
    # and a source whose root was edited to somewhere narrower should not
    # keep reading the old tree.
    def read(external_id)
      root = Pathname.new(path).cleanpath
      absolute = root.join(external_id).cleanpath

      unless absolute.to_s == root.to_s || absolute.to_s.start_with?("#{root}/")
        raise OutsideRootError, "#{external_id} resolves outside #{root}"
      end

      File.binread(absolute)
    end

    private

    # The item's directory relative to the root, or nil at the top level —
    # File.dirname answers "." there, which is not a breadcrumb.
    def directory_of(relative)
      directory = File.dirname(relative)
      directory unless directory == "."
    end

    # True if any path segment starts with a dot, so a file inside a hidden
    # directory is hidden too.
    def hidden?(relative)
      relative.split(File::SEPARATOR).any? { |segment| segment.start_with?(".") }
    end

    # An oversized file is still *reported* — it is in the folder, we simply
    # won't ingest it. That distinction matters because the limit is
    # configurable: lowering ARCHYVE_MAX_FILE_SIZE_MB would otherwise make files
    # vanish from the scan, and anything missing from a scan gets tombstoned. A
    # setting change would quietly delete documents whose files never moved.
    def size_skip_reason(size)
      return if size <= self.class.max_file_size

      "larger than the #{ActiveSupport::NumberHelper.number_to_human_size(self.class.max_file_size)} limit"
    end

    def path_must_be_an_absolute_directory
      pathname = Pathname.new(path)

      if !pathname.absolute?
        errors.add(:path, "must be an absolute path")
      elsif !pathname.directory?
        errors.add(:path, "is not a directory Archyve can see")
      elsif !pathname.readable?
        errors.add(:path, "is not readable by Archyve")
      end
    end
  end
end
