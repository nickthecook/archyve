# frozen_string_literal: true

# One block of what the model wrote: markdown rendered, citation markers turned
# into links. The rendering itself is Chat::Prose — this is the part that knows
# *which* results a handle refers to.
#
# Handles are resolved against the retrieval segment *preceding* this prose in
# the same turn, because that is the set the model was looking at when it wrote
# them. Handle 1 means something different in each block.
class Views::Conversations::Cited < Components::Base
  def initialize(segment:)
    @segment = segment
  end

  def view_template
    raw safe(Chat::Prose.call(@segment.content, hits: hits))
  end

  private

  # The hits of the nearest retrieval segment above this one in the turn.
  def hits
    @hits ||= @segment.message.segments
      .select { it.retrieval? && it.position < @segment.position }
      .last
      &.hits
      &.index_by(&:handle) || {}
  end
end
