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
  # Every bracket a model reaches for, not only the one it was asked to use.
  #
  # The instructions say to write [1], and models write what they like: gpt-oss
  # emits the CJK 【1】, others the fullwidth ［1］, and several group their
  # sources as [1, 2]. A citation that doesn't match is a citation that doesn't
  # link, which is the whole feature gone — and no amount of prompting makes a
  # local model consistent about punctuation. Cheaper to read all of them.
  OPEN = "\\[\\u3010\\uFF3B".freeze
  CLOSE = "\\]\\u3011\\uFF3D".freeze
  SEPARATOR = /\s*[,;]\s*/
  MARKER = /[#{OPEN}]\s*(\d{1,2}(?:#{SEPARATOR.source}\d{1,2})*)\s*[#{CLOSE}]/

  def initialize(segment:)
    @segment = segment
  end

  def view_template
    @segment.content.to_s.split(MARKER).each_with_index do |part, index|
      # split with a capture group alternates literal text and captured handles.
      index.odd? ? citations(part) : plain(part)
    end
  end

  private

  # One bracket may hold several handles. Each is resolved on its own, so a
  # group like [1, 7] where only 1 was retrieved keeps the good citation
  # instead of discarding both.
  def citations(group)
    group.split(SEPARATOR).each { |handle| citation(handle.to_i) }
  end

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
