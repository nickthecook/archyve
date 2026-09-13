# One turn in a conversation, by one party.
#
# A message holds no text. Everything said is a segment, including a user's
# question, which is a message with exactly one text segment — see Segment for
# why a turn is a sequence rather than a blob.
class Message < ApplicationRecord
  belongs_to :conversation, touch: true

  # Which model wrote this turn, for assistant turns. Optional twice over: a
  # user's turn was written by a person, and an admin removing a model nullifies
  # the reference rather than rewriting history.
  belongs_to :inference_model, optional: true

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

  # Whether the model is still working on this turn. A user's turn is complete
  # the moment it exists; only an assistant's is ever in flight.
  def in_progress? = assistant? && completed_at.nil?

  # What the page should say it is waiting for. The gap after a search is the
  # long one — the model re-reads everything it was handed before its first
  # token — and it is the gap most likely to look like a hang.
  def waiting_on
    return unless in_progress?
    return "Reading the results…" if segments.last&.retrieval?

    # Thinking segments don't count: the model reasoning out loud isn't the
    # answer arriving, and the spinner is what says the answer is still coming.
    "Thinking…" if segments.none? { it.text? && it.content.present? }
  end

  def next_segment_position = (segments.maximum(:position) || 0) + 1
end
