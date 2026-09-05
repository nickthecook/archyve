class Embedding < ApplicationRecord
  # The active embedding model for the corpus. Changing this is a corpus-wide
  # decision that requires re-embedding (embeddings across models aren't
  # comparable). Kept here for now; move to config when we support switching.
  DEFAULT_MODEL = "nomic-embed-text:v1.5".freeze
  DIMENSIONS = 768

  has_neighbors :embedding

  belongs_to :chunk

  validates :embedding_model, presence: true
  validates :chunk_id, uniqueness: { scope: :embedding_model }
end
