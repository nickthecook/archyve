# frozen_string_literal: true

# One block of what the model wrote: markdown rendered, citation markers turned
# into buttons, and the card each one opens. The rendering itself is Chat::Prose
# — this is the part that knows *which* results a handle refers to.
#
# Handles are resolved against every search and read *preceding* this prose in
# the same turn, because handles run on across a turn rather than restarting in
# each block — so prose written after a second search can still cite the first.
#
# The cards sit outside the `answer` div so answer.css, which styles the
# model's markdown by element, can't reach into them.
class Views::Conversations::Cited < Components::Base
  # `hits` prebuilt is the streaming path: Chat::Turn already holds the map for
  # the search this prose follows, and the lookback below would otherwise walk
  # every segment of the message on every tick of the stream. nil means work it
  # out — which is what a page render, holding no such context, has to do.
  def initialize(segment:, hits: nil)
    @segment = segment
    @hits = hits
  end

  def view_template
    prose = Chat::Prose.new(@segment.content, hits:, popover_id: method(:popover_id))

    # `answer` is the hook for answer.css. No whitespace-pre-wrap: the HTML
    # carries its own block layout, and pre-wrap would render the newlines
    # *between* its tags as blank lines.
    div(id: Views::Conversations::Segment.prose_dom_id(@segment),
        class: "answer scroll-mt-6 text-[0.95rem] leading-relaxed text-muted") do
      raw safe(prose.call)
    end
    prose.cited.each { render Views::Conversations::CitationCard.new(hit: it, id: popover_id(it)) }
  end

  private

  # Per segment, not per hit: two blocks of one answer can cite the same hit,
  # and each needs a card of its own id.
  def popover_id(hit) = "#{Views::Conversations::Segment.dom_id(@segment)}_citation_#{hit.handle}"

  # Every hit put in front of the model above this prose, in one map.
  # An empty map is a real answer — prose written before any search has no
  # citations to resolve — so this memoises on nil rather than on blank, and a
  # caller that passes {} gets {} instead of a walk.
  def hits
    @hits ||= @segment.message.segments.includes(hits: { document: :source })
      .select { it.sourced? && it.position < @segment.position }
      .flat_map(&:hits)
      .index_by(&:handle)
  end
end
