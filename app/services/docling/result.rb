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
    #
    # `text` and `markdown` are the same element said twice: plain for the
    # embedding and the model's prompt, marked up for display. One walk produces
    # both, so the two can't come to describe different elements.
    Item = Data.define(:text, :markdown, :label, :level, :page) do
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
      items_for(children_of(body))
    end

    private

    def body = json_content["body"] || {}

    def items_for(nodes) = nodes.flat_map { |node| node_items(node) }

    # A list is pure structure — it holds blocks, not words — so it contributes
    # nothing of its own. Anything else is an element, and may still own the
    # blocks that follow it.
    def node_items(node)
      return items_for(children_of(node)) if container?(node)

      Array(item_for(node)) + items_for(block_children(node))
    end

    def item_for(node)
      leaves = leaves_under(node)
      return if leaves.empty?

      Item.new(
        text: join(leaves.map { it["text"].strip }),
        markdown: disarm(join(leaves.map { decorate(it) })),
        label: label_for(node),
        level: level_for(node),
        page: page_under(node)
      )
    end

    # The fragments carrying this element's text, in document order. A list
    # item's own entry is blank and its words hang below it, so a node
    # contributes itself *and* its fragments rather than one or the other.
    def leaves_under(node)
      own = node["text"].to_s.strip.empty? ? [] : [node]
      own + fragment_children(node).flat_map { |child| leaves_under(child) }
    end

    # Docling nests two different things the same way, and telling them apart is
    # the whole job. An `inline` group's children are fragments of one paragraph.
    # A text node's children are the blocks *beneath* it — in the hierarchical
    # shape docling emits for some documents, a heading owns its entire section.
    # Reading the second kind as the first collapses a document into its title.
    # An inline group's children are all fragments of it. Below anything else,
    # an inline group is a fragment only when the node has no text of its own —
    # that is a list item, whose words hang beneath a blank entry. A node that
    # *does* carry its own text already has all of it, and an inline group under
    # that is the next block down: an HTML heading owns the paragraphs of its
    # section this way, and reading them as more of the heading swallows the
    # section into it.
    def fragment_children(node)
      return children_of(node) if inline?(node)
      return [] if node["text"].to_s.strip.present?

      children_of(node).select { inline?(it) }
    end

    # Whatever the node's own text did not account for. Set difference rather
    # than the opposite predicate, so the two can never both claim a child or
    # both disown one.
    def block_children(node) = inline?(node) ? [] : children_of(node) - fragment_children(node)

    # Fragments rejoin with a space, as docling's own serializer does, minus the
    # stray space that leaves in front of punctuation trailing a link or an
    # emphasised run.
    def join(parts) = parts.join(" ").gsub(/\s+(?=[,.;:!?)\]])/, "")

    # Docling keeps the inline detail markdown was written with — `formatting`
    # per fragment, `hyperlink` for a link's anchor text — so the display form
    # can be put back rather than approximated. Underline and sub/superscript
    # have no markdown spelling and are dropped.
    def decorate(leaf)
      format = leaf["formatting"] || {}
      text = escape(leaf["text"].strip)
      text = "**#{text}**" if format["bold"]
      text = "*#{text}*" if format["italic"]
      text = "~~#{text}~~" if format["strikethrough"]
      leaf["hyperlink"].present? ? "[#{text}](#{leaf['hyperlink']})" : text
    end

    # Document text is not markdown and must not be read as it: a chunk about
    # `snake_case_names` should not come out half-italic, and a manual that says
    # "Bee~ree" should not strike itself through.
    def escape(text) = text.gsub(/[\\`*_\[\]<>~|]/) { "\\#{it}" }

    # Inline escaping is not enough. An item's markdown is a single line, so text
    # that merely *begins* the way a heading or a list begins opens a block that
    # was never in the document — a numbered step ("1. Touch the pad") is the
    # one that turns up constantly in scanned manuals. A digit can't take a
    # backslash, so there the delimiter after it is escaped instead.
    def disarm(text)
      text.sub(/\A(\#{1,6}|[-+]|\d{1,9}[.)])(?=\s|\z)/) do |marker|
        marker.end_with?(".", ")") ? "#{marker[..-2]}\\#{marker[-1]}" : "\\#{marker}"
      end
    end

    def page_under(node)
      (node["prov"] || []).first&.dig("page_no") ||
        children_of(node).filter_map { |child| page_under(child) }.first
    end

    def children_of(node) = Array(node["children"]).filter_map { |ref| resolve(ref) }

    # A group that is not `inline` is structure (a list); an inline group *is*
    # the paragraph, so it becomes one item rather than being walked into.
    def container?(node) = group?(node) && !inline?(node)

    def inline?(node) = group?(node) && node["label"] == "inline"

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
