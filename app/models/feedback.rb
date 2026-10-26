# What the person who asked thought of one answer. A comment needs no rating.
class Feedback < ApplicationRecord
  belongs_to :message

  enum :rating, { up: 0, down: 1 }, validate: { allow_nil: true }

  COMMENT_LIMIT = 1000

  normalizes :comment, with: -> { it.strip.presence }
  validates :comment, length: { maximum: COMMENT_LIMIT }

  scope :commented, -> { where.not(comment: nil) }

  def empty? = rating.nil? && comment.nil?
end
