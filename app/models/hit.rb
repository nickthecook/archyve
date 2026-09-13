# One chunk the model was shown, recorded as it was shown.
#
# `handle` is the citation label the model is given — "1", "2" — and the only
# name it ever has for a source. It cites the handle, Archyve resolves the
# handle to a link, so the model can neither author a URL nor cite a document
# that wasn't retrieved. Positional within its segment, so handle 1 exists in
# every retrieval block and means something different in each.
#
# The chunk and document are nullable on purpose. Reingesting a document
# destroys its chunks and makes new ones; a chat from last week must not lose
# its citations because a source synced overnight. When they survive, they power
# the link and the chunk inspector. When they don't, `snippet` still shows what
# the answer was actually based on — which is the more important half, since the
# question you bring to an old transcript is usually "what was it told?"
class Hit < ApplicationRecord
  belongs_to :segment
  belongs_to :chunk, optional: true
  belongs_to :document, optional: true

  validates :handle, presence: true, uniqueness: { scope: :segment_id }
  validates :snippet, :document_title, presence: true
  validates :distance, :score, presence: true

  # Cosine distance (0 identical … 2 opposite) → a friendly percentage. Not the
  # sort key — hits are ordered by fused score — so the UI renders it quietly.
  def similarity = ((1 - distance) * 100).round.clamp(0, 100)

  # Whether this citation can still be followed to the live document.
  def followable? = document.present?

  # Where following it leads: the document, and the exact passage inside it when
  # the chunk survived. Straight to the chunk because a citation exists to
  # answer "where does this come from?" — a reader who has to find the passage
  # in a wall of similar cards is doing the work the handle was supposed to do.
  #
  # Falls back to the document when reingestion has replaced the chunk, and to
  # nil when the document is gone, which is `followable?` by another name.
  #
  # A model reaching for a route helper, because both renderings of a hit need
  # the same link — the inline citation marker and the retrieval panel's card —
  # and routes.rb is the only place /documents/:id is defined.
  def href
    return unless followable?

    path = Rails.application.routes.url_helpers.document_path(document_id)
    chunk_id ? "#{path}##{Chunk.anchor(chunk_id)}" : path
  end

  # The title as it is now, falling back to the one recorded at retrieval. A
  # renamed document reads under its current name; a deleted one still reads
  # under the name it had when it was cited.
  def title = document&.title || document_title
end
