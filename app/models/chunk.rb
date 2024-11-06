class Chunk < ApplicationRecord
  belongs_to :document
  has_one :collection, through: :document
  has_many :graph_entity_descriptions, dependent: :destroy
  has_many :graph_relationships, dependent: :destroy
  has_many :graph_entities, through: :entity_descriptions
  has_many :api_calls, as: :traceable, dependent: :destroy
  has_many :message_augmentations, as: :augmentation, dependent: :destroy

  scope :embedded, -> { where.not(vector_id: nil) }
  scope :extracted, ->  { where(entities_extracted: true) }

  # Require embedding content when creating new chunks
  # Schema doesn't enforce presence for backwards compatibility with existing data
  validate :explicit_embedding_content?, on: :create

  def previous(count = 1)
    self.class.where(document:).where("id < ?", id).order(id: :asc).last(count)
  end

  def next(count = 1)
    self.class.where(document:).where("id > ?", id).order(id: :asc).first(count)
  end

  def embedding_content
    # This will help with any previously ingested documents which will
    # have a nil for this column
    self[:embedding_content] || excerpt
  end

  private

  def explicit_embedding_content?
    return false if self[:embedding_content]

    errors.add(:embedding_content, "New chunks require embedding content")
  end
end
