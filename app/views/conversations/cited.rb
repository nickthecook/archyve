# frozen_string_literal: true

# One block of what the model wrote: markdown rendered, citation markers turned
# into links. The rendering itself is Chat::Prose — this is the part that knows
# *which* results a handle refers to.
#
# Handles are resolved against the retrieval segment *preceding* this prose in
# the same turn, because that is the set the model was looking at when it wrote
# them. Handle 1 means something different in each block.
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
    raw safe(Chat::Prose.call(@segment.content, hits: hits))
  end

  private

  # The hits of the nearest retrieval segment above this one in the turn.
  # An empty map is a real answer — prose written before any search has no
  # citations to resolve — so this memoises on nil rather than on blank, and a
  # caller that passes {} gets {} instead of a walk.
  def hits
    @hits ||= @segment.message.segments
      .select { it.retrieval? && it.position < @segment.position }
      .last
      &.hits
      &.index_by(&:handle) || {}
  end
end
