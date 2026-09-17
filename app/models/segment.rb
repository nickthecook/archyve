# One contiguous piece of a turn, in the order it was produced.
#
# A reply that searches the archive is three segments — prose, retrieval, prose
# — and keeping them ordered is what lets the transcript show the pause where it
# actually happened rather than tidying the tool call away into a footnote.
#
# Three kinds, and they use different columns:
#
#   text       `content` — prose, rendered as paragraphs
#   thinking   `content` — the model's own reasoning, collapsed in the transcript
#   retrieval  `queries`, `candidate_count`, `failure_kind`, and its hits
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

  enum :kind, { text: 0, retrieval: 1, thinking: 2 }, validate: true

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

  # The two kinds that are words in `content`. Kept as a predicate rather than
  # `text? || thinking?` at each call site so a fourth kind has one place to
  # declare itself as prose.
  def prose? = text? || thinking?

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

    outcome.hits.each do |hit|
      hits.create!(
        handle: hit.handle, chunk: hit.chunk, document: hit.document,
        distance: hit.distance, score: hit.score,
        snippet: hit.chunk.content, document_title: hit.document.title,
        heading_path: hit.heading_path.presence
      )
    end
  end

  private

  def quoted_queries = Array(queries).map { "“#{it}”" }.to_sentence

  def history_line(hit)
    section = hit.heading_path.present? ? " (#{hit.heading_path})" : ""
    "[#{hit.handle}] #{hit.document_title}#{section}: #{hit.snippet}"
  end
end
