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
    return "Reading the document…" if segments.last&.reading?
    return "Reading the listing…" if segments.last&.listing?

    # Thinking segments don't count: the model reasoning out loud isn't the
    # answer arriving, and the spinner is what says the answer is still coming.
    "Thinking…" if segments.none? { it.text? && it.content.present? }
  end

  def next_segment_position = (segments.maximum(:position) || 0) + 1

  # What share of the model's context window this turn's prompt filled, or nil
  # when either number is unknown — a provider that reported no usage, or a
  # model whose window nobody has filled in. Can exceed 1: the window is what
  # Archyve was told, and a server started with less will have truncated.
  def context_fraction
    window = inference_model&.context_window
    return if input_tokens.nil? || window.nil?

    input_tokens.to_f / window
  end

  # How fast the model ran for this turn — every token it produced over the time
  # it spent producing them. The turn's rate rather than any one segment's,
  # because it sits beside the attribution, which is the turn's too.
  #
  # Summing the spans rather than measuring end to end is the point: a turn that
  # searched spent seconds waiting on the archive and on its own prompt, and
  # those are not the model generating slowly. What is left is generation.
  def tokens_per_second
    tokens = segments.sum { it.token_count.to_i }
    elapsed = segments.sum { it.generation_ms.to_i }
    return if tokens.zero? || elapsed.zero?

    tokens * 1000.0 / elapsed
  end
end
