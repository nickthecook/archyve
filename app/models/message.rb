# One turn in a conversation, by one party.
#
# A message holds no text. Everything said is a segment, including a user's
# question, which is a message with exactly one text segment — see Segment for
# why a turn is a sequence rather than a blob.
class Message < ApplicationRecord
  belongs_to :conversation, touch: true

  has_many :segments, -> { order(:position) }, dependent: :destroy, inverse_of: :message

  enum :role, { user: 0, assistant: 1 }, validate: true

  validates :position, presence: true, uniqueness: { scope: :conversation_id }

  # Everything a person said, which is always one segment's worth.
  def text = segments.filter_map(&:content).join("\n\n")

  # This turn as the model should see it when the conversation is replayed —
  # prose, plus any searches it ran and what they returned. See
  # Segment#for_history for why past retrievals are replayed at all.
  def history_content = segments.filter_map(&:for_history).join("\n\n")

  def failed? = error.present?

  def next_segment_position = (segments.maximum(:position) || 0) + 1
end
