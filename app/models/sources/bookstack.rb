module Sources
  # Pages from a BookStack wiki, reached through an Endpoints::Bookstack.
  #
  # A **page** is a Document and nothing else is. Shelves, books and chapters
  # contribute their names as the document's path and their descriptions as
  # metadata, but never become documents themselves — see docs/todo.md, "The
  # BookStack source", for why their descriptions are poison in a similarity
  # contest.
  #
  # Identity is the page id, so a page that moves between books is the same
  # document rather than a delete plus a create — the thing Folder can't do.
  class Bookstack < Source
    # BookStack's own ceiling for `count` on a list endpoint.
    PAGE_SIZE = 500

    # The export endpoint returns the author's markdown, so there is exactly one
    # conversion between what they wrote and what gets chunked.
    CONTENT_TYPE = "text/markdown".freeze

    # What a selector may name.
    SELECTOR_KINDS = %w[shelf book chapter].freeze

    # What was picked, never its expansion: `[{"shelf" => 3}, {"book" => 12}]`,
    # resolved to a page set at scan time. "Sync this shelf" has to mean "and
    # whatever lands on it later".
    store_accessor :config, :selectors

    # One thing you can tick in the selector picker. `context` is the book a
    # chapter sits in — chapter names repeat across books, and "Installation" on
    # its own is not a choice anyone can make.
    Container = Data.define(:kind, :id, :name, :context) do
      def token = "#{kind}:#{id}"
    end

    # What the picker needs to draw itself, and why it couldn't when it can't:
    # the list comes from a live call, so a wiki that is down or a token that
    # has been rotated has to render as a sentence rather than a 500.
    Catalogue = Data.define(:containers, :error)

    validates :selectors, presence: true
    validate :selectors_must_name_a_container, if: -> { selectors.present? }

    def self.endpoint_type = Endpoints::Bookstack
    def self.supports_sync? = true
    def self.user_creatable? = true
    def self.type_label = "BookStack"
    def self.form_component = Views::Sources::Forms::Bookstack

    def location = endpoint&.host

    # The markdown export carries image *links*, not images, so there is nothing
    # in the document to read text from.
    def self.supports_ocr? = false

    # The first source type that can hand a reader the live document instead of
    # a copy of it.
    def self.user_accessible_links? = true

    def self.description
      "Pages from a BookStack wiki, chosen by shelf, book or chapter. Read, never written."
    end

    # `[{"book" => 12}]` as `[["book", 12]]`, dropping anything malformed — the
    # validation below is what stops malformed selectors being saved, so by scan
    # time this only guards against hand-edited jsonb.
    def selections
      Array(selectors).filter_map do |entry|
        next unless entry.is_a?(Hash) && entry.size == 1

        kind, id = entry.first
        next unless SELECTOR_KINDS.include?(kind.to_s) && id.to_i.positive?

        [kind.to_s, id.to_i]
      end
    end

    # Everything tickable in the selector picker, or the reason the wiki couldn't
    # say. Recorded rather than raised, the same way Endpoint#access records it.
    # `at` is ignored: the whole catalogue is three calls, so there is nowhere to
    # browse to.
    def catalogue(at: nil)
      return Catalogue.new(containers: [], error: nil) if endpoint.blank?

      Catalogue.new(containers: load_containers, error: nil)
    rescue StandardError => e
      Rails.logger.error("source #{id} could not list #{endpoint.name}: #{e.class}: #{e.message}")
      Catalogue.new(containers: [], error: "#{e.class}: #{e.message}")
    end

    # Accepts what the picker submits ("book:12") as readily as what is stored
    # ({"book" => 12}), so the controller can permit a plain array of strings.
    # Unrecognisable entries are kept, not dropped — the validation above is
    # what refuses them, and silently discarding them would turn a typo into a
    # source that syncs less than it was told to.
    def selectors=(value)
      super(Array(value).reject(&:blank?).map { |entry| normalize_selector(entry) })
    end

    # Yields an Item per page in the selected containers.
    #
    # The containers come back wholesale — the wiki has orders of magnitude
    # fewer books, chapters and shelves than pages — and the page list is
    # filtered in Ruby against them. No page body is fetched here; that is
    # ImportItemJob's call, for the pages whose version actually moved.
    def each_item(_run = nil)
      return enum_for(:each_item) unless block_given?

      books = by_id(index("/api/books"))
      chapters = by_id(index("/api/chapters"))
      book_ids, chapter_ids = resolve(books, chapters)

      index("/api/pages").each do |page|
        # Somebody's unfinished sentence, and boilerplate with no subject.
        # Passed over silently, the way Folder passes over a .DS_Store.
        next if page["draft"] || page["template"]

        book = books[page["book_id"]]
        chapter = chapters[page["chapter_id"]]
        next unless book && (book_ids.include?(book["id"]) || chapter_ids.include?(chapter&.fetch("id", nil)))

        yield item_for(page, book, chapter)
      end
    end

    def read(external_id)
      client.get("/api/pages/#{external_id}/export/markdown").body
    end

    def document_url(document) = document.url

    # external_id is a page id, which carries no extension, and Docling picks
    # its reader off one.
    def filename_for(document)
      "#{document.title.to_s.parameterize.presence || document.external_id}.md"
    end

    private

    def normalize_selector(entry)
      return entry unless entry.is_a?(String)

      kind, id = entry.split(":", 2)
      { kind => id.to_i }
    end

    def client
      @client ||= endpoint.client
    end

    # The version token is the revision marker alone — deliberately not the
    # computed path. `updated_at` over `revision_count` because every BookStack
    # resource carries it and it moves on saves that mint no revision; it
    # over-reports, and ImportItemJob's checksum catches that for the price of
    # one fetch, the same bargain Folder strikes with mtime.
    def item_for(page, book, chapter)
      Item.new(
        external_id: page["id"].to_s,
        version: page["updated_at"].to_s,
        title: page["name"],
        content_type: CONTENT_TYPE,
        path: [book["name"], chapter&.fetch("name", nil)].compact.join("/"),
        url: "#{endpoint.base_url}/books/#{book["slug"]}/page/#{page["slug"]}",
        metadata: metadata_for(book, chapter)
      )
    end

    # Container descriptions are stored and shown, never embedded.
    def metadata_for(book, chapter)
      {
        "book" => book["name"],
        "book_description" => book["description"].presence,
        "chapter" => chapter&.fetch("name", nil),
        "chapter_description" => chapter&.fetch("description", nil).presence
      }.compact
    end

    # Selectors to the ids a page is matched against. A book takes every page in
    # it, chaptered or not; a chapter takes only its own.
    def resolve(books, chapters)
      book_ids = Set.new
      chapter_ids = Set.new

      selections.each do |kind, id|
        case kind
        when "book" then book_ids << id if books.key?(id)
        when "chapter" then chapter_ids << id if chapters.key?(id)
        when "shelf" then book_ids.merge(books_on_shelf(id))
        end
      end

      [book_ids, chapter_ids]
    end

    # A shelf's books are only on the shelf's own record, so this is one extra
    # call per *selected* shelf rather than per shelf in the wiki.
    def books_on_shelf(shelf_id)
      get("/api/shelves/#{shelf_id}").fetch("books", []).map { |book| book["id"] }
    end

    # Every page of a list endpoint. BookStack caps `count` and reports the full
    # `total`, so this is the whole collection in ceil(total / PAGE_SIZE) calls.
    def index(path)
      results = []

      loop do
        body = get(path, count: PAGE_SIZE, offset: results.size)
        batch = body.fetch("data", [])
        results.concat(batch)
        break if batch.empty? || results.size >= body.fetch("total", 0).to_i
      end

      results
    end

    def get(path, params = {})
      JSON.parse(client.get(path, params).body)
    end

    def by_id(records)
      records.index_by { |record| record["id"] }
    end

    def selectors_must_name_a_container
      return if selections.size == Array(selectors).size

      errors.add(:selectors, "must each name one shelf, book or chapter")
    end

    # Shelves, books and chapters — three calls, and pointedly not the page
    # list, which is the expensive one.
    def load_containers
      books = by_id(index("/api/books"))

      index("/api/shelves").map { |shelf| Container.new("shelf", shelf["id"], shelf["name"], nil) } +
        books.each_value.map { |book| Container.new("book", book["id"], book["name"], nil) } +
        index("/api/chapters").map do |chapter|
          Container.new("chapter", chapter["id"], chapter["name"], books.dig(chapter["book_id"], "name"))
        end
    end
  end
end
