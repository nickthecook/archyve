class Embedding < ApplicationRecord
  DIMENSIONS = 768
  COLUMNS_BY_DIMENSION = { 768 => :embedding, 1536 => :embedding_1536 }.freeze

  has_neighbors :embedding
  has_neighbors :embedding_1536

  def self.column_for(dimensions) = COLUMNS_BY_DIMENSION.fetch(dimensions)

  belongs_to :chunk

  validates :embedding_model, presence: true
  validates :chunk_id, uniqueness: { scope: :embedding_model }

  # What the archive's vectors were produced by, or nil when there are none.
  # This name is the way back from a removed embedding model: a replacement row
  # has to claim it exactly, or InferenceModel#corpus_must_be_empty refuses it
  # for stranding everything already stored.
  def self.corpus_model = distinct.pick(:embedding_model)
end
