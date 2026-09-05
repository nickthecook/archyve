class Chunk < ApplicationRecord
  belongs_to :document
  has_many :embeddings, dependent: :destroy

  validates :position, presence: true, uniqueness: { scope: :document_id }
  validates :content, presence: true
end
