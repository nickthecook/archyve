# frozen_string_literal: true

# One block of what the model wrote: markdown rendered, citation markers turned
# into links. The rendering itself is Chat::Prose — this is the part that knows
# *which* results a handle refers to.
#
# Handles are resolved against every search and read *preceding* this prose in
# the same turn, because handles run on across a turn rather than restarting in
# each block — so prose written after a second search can still cite the first.
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

  # Every hit put in front of the model above this prose, in one map.
  # An empty map is a real answer — prose written before any search has no
  # citations to resolve — so this memoises on nil rather than on blank, and a
  # caller that passes {} gets {} instead of a walk.
  def hits
    @hits ||= @segment.message.segments
      .select { it.sourced? && it.position < @segment.position }
      .flat_map(&:hits)
      .index_by(&:handle)
  end
end
