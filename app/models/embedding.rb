class Embedding < ApplicationRecord
  # The width of the `embedding` column: a vector(768) with a single cosine
  # HNSW index. A schema fact rather than a setting, which is why it stayed a
  # constant when the model id moved to InferenceModel — that row is validated
  # against this, since a model of any other width could not be stored here.
  DIMENSIONS = 768

  has_neighbors :embedding

  belongs_to :chunk

  validates :embedding_model, presence: true
  validates :chunk_id, uniqueness: { scope: :embedding_model }
end
