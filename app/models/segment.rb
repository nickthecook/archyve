# One contiguous piece of a turn, in the order it was produced.
#
# A reply that searches the archive is three segments — prose, retrieval, prose
# — and keeping them ordered is what lets the transcript show the pause where it
# actually happened rather than tidying the tool call away into a footnote.
#
# Two kinds, and they use different columns:
#
#   text       `content` — prose, rendered as paragraphs
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

  enum :kind, { text: 0, retrieval: 1 }, validate: true

  validates :position, presence: true, uniqueness: { scope: :message_id }
  validates :content, presence: true, if: :text?

  # Mirrors Retrieval::Failure#kind, as a string rather than an enum so the two
  # vocabularies can't drift apart silently.
  FAILURE_KINDS = %w[not_configured unreachable].freeze
  validates :failure_kind, inclusion: { in: FAILURE_KINDS }, allow_nil: true

  def failed? = failure_kind.present?

  # Retrieval ran and came back empty — the honest "your archive doesn't cover
  # this", which a failure must never be mistaken for.
  def found_nothing? = retrieval? && !failed? && hits.empty?

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
end
