class Chunk < ApplicationRecord
  belongs_to :document
  has_many :embeddings, dependent: :destroy

  validates :position, presence: true, uniqueness: { scope: :document_id }
  validates :content, presence: true

  # The dom id of this chunk's card on documents#show, and so the fragment that
  # deep-links to it. Defined here because three places need to agree on it —
  # the card that carries the id, the search result, and the chat citation — and
  # takes a bare id as well as a record: a citation holds `chunk_id` and has no
  # reason to load the row just to name it.
  def self.anchor(id) = "#{ActionView::RecordIdentifier.dom_class(self)}_#{id}"

  def anchor = self.class.anchor(id)
end
