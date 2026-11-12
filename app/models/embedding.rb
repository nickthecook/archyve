class Embedding < ApplicationRecord
  # One vector column per supported width, each with its own cosine HNSW index:
  # pgvector can't index a column of mixed dimensions. A schema fact, so a
  # constant — InferenceModel validates its dimensions against these keys.
  COLUMNS = { 768 => :embedding_768, 1536 => :embedding_1536 }.freeze

  has_neighbors(*COLUMNS.values)

  belongs_to :chunk

  validates :embedding_model, presence: true
  validates :chunk_id, uniqueness: { scope: :embedding_model }

  def self.column_for(dimensions) = COLUMNS.fetch(dimensions)

  # What the archive's vectors were produced by, or nil when there are none.
  # This name is the way back from a removed embedding model: a replacement row
  # has to claim it exactly, or InferenceModel#corpus_must_be_empty refuses it
  # for stranding everything already stored.
  def self.corpus_model = distinct.pick(:embedding_model)

  def vector=(values)
    self[self.class.column_for(values.size)] = values
  end
end
