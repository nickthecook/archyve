module Docling
  # Wraps a docling-serve conversion response. The chunker consumes `items`
  # (the flattened, ordered text elements with their structural labels); the
  # markdown is kept for display/debugging.
  class Result
    # One text element from the DoclingDocument body, normalized for chunking.
    # `label` is Docling's semantic role (title, section_header, text, list_item,
    # caption, ...); `level` is the heading depth for section_header/title; `page`
    # is the source page number when the input carried provenance (PDFs do,
    # markdown/plain text don't).
    Item = Data.define(:text, :label, :level, :page) do
      def heading? = label == "section_header" || label == "title"
    end

    HEADING_LABELS = %w[title section_header].freeze

    attr_reader :raw

    def initialize(raw)
      @raw = raw
    end

    def document = raw["document"] || {}
    def markdown = document["md_content"]
    def json_content = document["json_content"] || {}
    def errors = raw["errors"] || []
    def status = raw["status"]

    # Docling grades its own work, and the middle grade is the useful one: a
    # `partial_success` is a converted document with a page or two missing, and
    # the pages that did convert are right here in `json_content`. Treating that
    # as a failure throws away a whole manual to punish one bad page.
    #
    # A "success" that still carries errors is counted as partial rather than
    # believed: the two claims contradict each other, and the cautious reading
    # is the one that keeps the caveat.
    def success? = status == "success" && errors.empty?
    def partial? = status == "partial_success" || (status == "success" && errors.any?)

    def title
      (json_content["texts"] || []).find { |t| t["label"] == "title" }&.dig("text")
    end

    # Ordered text elements, skipping empties. Titles are treated as level 0 so a
    # heading stack can sit the whole doc under the document title.
    def items
      (json_content["texts"] || []).filter_map do |t|
        text = t["text"].to_s.strip
        next if text.empty?

        level = t["label"] == "title" ? 0 : t["level"]
        page = (t["prov"] || []).first&.dig("page_no")
        Item.new(text: text, label: t["label"], level: level, page: page)
      end
    end
  end
end
