class Chunk < ApplicationRecord
  belongs_to :document
  has_one :collection, through: :document

  def previous(count = 1)
    self.class.where(document:).where("id < ?", id).order(id: :asc).last(count)
  end

  def next(count = 1)
    self.class.where(document:).where("id > ?", id).order(id: :asc).first(count)
  end

  def embedding_content
    # This will help with any previously ingested documents which will
    # have a nil for this column
    self[:embedding_content] || content
  end
end
