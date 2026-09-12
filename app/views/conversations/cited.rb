# frozen_string_literal: true

# Prose with its citation markers turned into links.
#
# The model writes [1]; this finds the hit with that handle and renders a link
# to the document. **A handle that doesn't match a hit is left as plain text**,
# not rendered as a broken link — the model can invent "[7]" when only six
# results came back, and the honest rendering of an invented citation is to
# show it as the literal thing it is rather than dress it up as a source.
#
# Handles are resolved against the retrieval segment *preceding* this prose in
# the same turn, because that is the set the model was looking at when it wrote
# them. Handle 1 means something different in each block.
class Views::Conversations::Cited < Components::Base
  MARKER = /\[(\d{1,2})\]/

  def initialize(segment:)
    @segment = segment
  end

  def view_template
    @segment.content.to_s.split(MARKER).each_with_index do |part, index|
      # split with a capture group alternates literal text and captured handle.
      index.odd? ? citation(part.to_i) : plain(part)
    end
  end

  private

  def citation(handle)
    hit = hits[handle]
    return plain("[#{handle}]") if hit.nil?

    a(
      href: hit.followable? ? "/documents/#{hit.document_id}" : nil,
      title: "#{hit.title}#{" › #{hit.heading_path}" if hit.heading_path.present?}",
      class: "mx-0.5 rounded-sm border border-accent/60 bg-accent/10 px-1 align-super " \
             "font-mono text-[0.7rem] text-accent tabular-nums hover:bg-accent/20 transition-colors"
    ) { handle.to_s }
  end

  # The hits of the nearest retrieval segment above this one in the turn.
  def hits
    @hits ||= @segment.message.segments
      .select { it.retrieval? && it.position < @segment.position }
      .last
      &.hits
      &.index_by(&:handle) || {}
  end
end
