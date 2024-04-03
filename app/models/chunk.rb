class Chunk < ApplicationRecord
  belongs_to :document
  has_one :collection, through: :document

  def previous(count = 1)
    self.class.where(document:).where("id < ?", id).order(id: :asc).last(count)
  end

  def next(count = 1)
    self.class.where(document:).where("id > ?", id).order(id: :asc).first(count)
  end
end
