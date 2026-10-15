# One contiguous piece of a turn, in the order it was produced.
#
# A reply that searches the archive is three segments — prose, retrieval, prose
# — and keeping them ordered is what lets the transcript show the pause where it
# actually happened rather than tidying the tool call away into a footnote.
#
# Five kinds, and they use different columns:
#
#   text       `content` — prose, rendered as paragraphs
#   thinking   `content` — the model's own reasoning, collapsed in the transcript
#   retrieval  `queries`, `candidate_count`, `failure_kind`, and its hits
#   reading    `reading` — which document and range was read, and its hits
#   listing    `listing` — what walking the archive listed, and no hits at all
#
# ## Three outcomes, not two
#
# A retrieval segment distinguishes found-something, found-nothing and
# couldn't-search, because a model handed an empty list will tell someone their
# archive doesn't cover a topic — confidently, and wrongly, when the truth is
# that the embedding server was down. `failure_kind` is what keeps those apart
# once the turn is on disk, the same way Retrieval::Outcome keeps them apart in
# memory.
class Segment < ApplicationRecord
  belongs_to :message

  has_many :hits, -> { order(:handle) }, dependent: :destroy, inverse_of: :segment

  # `reading` rather than `read`: the predicate Rails generates from it sits
  # beside ActiveRecord's own reading vocabulary without shadowing anything,
  # and "a reading segment" is what this is.
  enum :kind, { text: 0, retrieval: 1, thinking: 2, reading: 3, listing: 4 }, validate: true

  validates :position, presence: true, uniqueness: { scope: :message_id }
  validates :content, presence: true, if: :prose?

  # Mirrors Retrieval::Failure#kind, as a string rather than an enum so the two
  # vocabularies can't drift apart silently.
  FAILURE_KINDS = %w[not_configured unreachable].freeze
  validates :failure_kind, inclusion: { in: FAILURE_KINDS }, allow_nil: true

  def failed? = failure_kind.present?

  # How fast the model produced this segment, in tokens per second — nil for
  # anything that wasn't generated (a retrieval), for a turn from before this
  # was recorded, and for a segment so short that its first delta was also its
  # last. Recorded by Chat::Pace, which explains what the two columns mean.
  def tokens_per_second
    return if token_count.to_i.zero? || generation_ms.to_i.zero?

    token_count * 1000.0 / generation_ms
  end

  # Streamed for a measurable span, but with no count to show for it — the
  # server sent none and Archyve had no basis to assume one. The span is real,
  # which is what makes this worth naming: a turn that folded it in would
  # divide real seconds by missing tokens. See Message#tokens_per_second.
  def uncounted? = token_count.nil? && generation_ms.to_i.positive?

  # The two kinds that are words in `content`. Kept as a predicate rather than
  # `text? || thinking?` at each call site so a fourth kind has one place to
  # declare itself as prose.
  def prose? = text? || thinking?

  # The two kinds that put passages in front of the model, and so the two whose
  # hits a citation can resolve against. A listing is deliberately not one of
  # them: it names documents without showing a word of them.
  def sourced? = retrieval? || reading?

  # Retrieval ran and came back empty — the honest "your archive doesn't cover
  # this", which a failure must never be mistaken for.
  def found_nothing? = retrieval? && !failed? && hits.empty?

  # How this segment reads when it is replayed to the model as history.
  #
  # Past retrievals are replayed rather than dropped, so a follow-up like "which
  # of those needs the bastion?" still has the passages to work from. They are
  # replayed from the stored snippets — what the model was actually shown —
  # rather than re-read from the chunks, which may since have been reingested.
  #
  # This is a flattening: the tool call and its result come back as prose inside
  # the assistant's own turn rather than as a real tool exchange, because
  # reconstructing that would mean storing provider tool-call ids we have no
  # other use for. Worth revisiting if a model ever gets confused about who
  # searched.
  def for_history
    return content if text?
    return read_history if reading?
    return listing_history if listing?
    # Thinking is deliberately *not* replayed. It was never said to the person
    # asking, and handing a model its own previous reasoning invites it to carry
    # on from it rather than answer afresh — the reason providers drop the
    # analysis channel from history too.
    return nil if thinking?
    return "[searched the archive; retrieval was unavailable]" if failed?
    return "[searched the archive for #{quoted_queries} — no matches]" if hits.empty?

    ["[searched the archive for #{quoted_queries}]", *hits.map { history_line(it) }].join("\n")
  end

  # Records what a Retrieval::Outcome found, as it was found. The snippet and
  # heading path are copied rather than read through the chunk: reingesting a
  # document destroys its chunks, and a transcript that reads through would
  # quietly rewrite itself the next time a source synced.
  def record!(outcome)
    update!(candidate_count: outcome.candidate_count, failure_kind: outcome.failure&.kind&.to_s)
    record_hits(outcome.hits)
  end

  # What a read found, in the same shape. The range is written to the segment
  # rather than derived from the hits, because the hits outlive their chunks —
  # see the columns note above.
  def record_reading!(result)
    update!(reading: {
      "document_id" => result.document&.id, "title" => result.document&.title,
      "from" => result.from, "to" => result.to, "total" => result.total,
      "refusal" => result.refusal&.to_s
    }.compact)
    record_hits(result.hits)
  end

  # What walking the archive listed. No hits go with it: a listing shows no
  # passages, which is why it is its own kind rather than a reading that
  # happened to come back as titles.
  def record_listing!(result)
    update!(listing: {
      "kind" => result.kind.to_s, "title" => result.title, "entries" => result.entries,
      "from" => result.from, "to" => result.to, "total" => result.total,
      "refusal" => result.refusal&.to_s
    }.compact)
  end

  # What was read, and out of how much. Always says the total, so a whole short
  # document reads differently from the first page of a long one.
  def range
    span = reading_from == reading_to ? "chunk #{reading_from}" : "chunks #{reading_from}–#{reading_to}"
    "#{span} of #{reading_total}"
  end

  # The two listings show different columns, and the kind is what says which —
  # asking the entries what they look like would work until one of them changed.
  def listed_collections? = listing&.dig("kind") == "collections"
  def listed_title = listing&.dig("title")
  def listed_entries = Array(listing&.dig("entries"))
  def listed_from = listing&.dig("from")
  def listed_to = listing&.dig("to")
  def listed_total = listing&.dig("total")
  def listing_refused? = listing&.dig("refusal").present?

  def read_title = reading&.dig("title")
  def reading_from = reading&.dig("from")
  def reading_to = reading&.dig("to")
  def reading_total = reading&.dig("total")
  def refused? = reading&.dig("refusal").present?

  private

  def record_hits(found)
    found.each do |hit|
      hits.create!(
        handle: hit.handle, chunk: hit.chunk, document: hit.document,
        distance: hit.distance, score: hit.score, position: hit.chunk.position,
        snippet: hit.chunk.content, document_title: hit.document.title,
        heading_path: hit.heading_path.presence
      )
    end
  end

  # Replayed from the stored snippets, like a past search — see the note on
  # for_history. A refused read is replayed too: a model that isn't told its
  # last read failed will assume it succeeded and answer from nothing.
  def read_history
    return "[tried to read a document; it could not be read]" if refused? || read_title.nil?

    ["[read #{read_title}, #{range}]", *hits.map { history_line(it) }].join("\n")
  end

  # Replayed as a plain sentence: a listing has no passages to quote back and
  # nothing a later turn may cite. What it saw is still worth replaying, since
  # a follow-up like "read the second one" depends on it.
  def listing_history
    return "[tried to list a collection that isn't in this chat's scope]" if listing_refused?
    return "[listed the collections in this chat's scope: #{collection_lines}]" if listed_collections?

    "[listed documents #{listed_from}–#{listed_to} of #{listed_total} in #{listed_title}: #{document_lines}]"
  end

  def collection_lines
    listed_entries.map { "#{it['name']} (#{it['slug']}, #{it['documents']} #{'document'.pluralize(it['documents'])})" }
      .to_sentence.presence || "none"
  end

  def document_lines
    listed_entries.map { "#{it['id']} #{it['title']}" }.join("; ").presence || "none"
  end

  def quoted_queries = Array(queries).map { "“#{it}”" }.to_sentence

  def history_line(hit)
    section = hit.heading_path.present? ? " (#{hit.heading_path})" : ""
    "[#{hit.handle}] #{hit.document_title}#{section}: #{hit.snippet}"
  end
end
