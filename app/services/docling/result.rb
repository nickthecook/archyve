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

    # Ordered body elements, skipping empties. Titles are treated as level 0 so a
    # heading stack can sit the whole doc under the document title.
    #
    # Walking the body tree is the point: `texts` holds *inline fragments*, not
    # paragraphs. A hard-wrapped line, a link's anchor text and an emphasised run
    # are each their own entry, and the paragraph they belong to is recorded as
    # an `inline` group — as is a list item's text, leaving the `list_item` entry
    # itself blank. Starting from `body` also excludes the `furniture` layer,
    # where repeated page headers and footers live.
    def items
      items_in(body["children"])
    end

    private

    def body = json_content["body"] || {}

    def items_in(refs)
      Array(refs).flat_map do |ref|
        node = resolve(ref)
        next [] if node.nil?

        container?(node) ? items_in(node["children"]) : Array(item_for(node))
      end
    end

    def item_for(node)
      text = text_under(node)
      return if text.empty?

      Item.new(text: text, label: label_for(node), level: level_for(node), page: page_under(node))
    end

    # Fragments rejoin with a space, as docling's own serializer does, minus the
    # stray space that leaves in front of punctuation trailing a link or an
    # emphasised run.
    def text_under(node)
      fragments(node).join(" ").gsub(/\s+(?=[,.;:!?)\]])/, "")
    end

    def fragments(node)
      own = node["text"].to_s.strip
      nested = children_of(node).flat_map { |child| fragments(child) }
      own.empty? ? nested : [own, *nested]
    end

    def page_under(node)
      (node["prov"] || []).first&.dig("page_no") ||
        children_of(node).filter_map { |child| page_under(child) }.first
    end

    def children_of(node) = Array(node["children"]).filter_map { |ref| resolve(ref) }

    # A group that is not `inline` is structure (a list, a section); an inline
    # group *is* the paragraph, so it becomes one item rather than being walked
    # into.
    def container?(node) = group?(node) && node["label"] != "inline"

    def group?(node) = node["self_ref"].to_s.start_with?("#/groups/")

    def label_for(node) = group?(node) ? "text" : node["label"]

    def level_for(node) = node["label"] == "title" ? 0 : node["level"]

    def resolve(ref)
      path = ref.is_a?(Hash) ? ref["$ref"] : ref
      kind, index = path.to_s.match(%r{\A#/(\w+)/(\d+)\z})&.captures
      kind && json_content[kind]&.at(index.to_i)
    end
  end
end
