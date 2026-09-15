# One chat with the archive.
#
# A conversation's retrieval scope is chosen when it starts and fixed for its
# lifetime: changing what you're drawing on means starting a new chat. That's a
# deliberate simplification rather than a limitation we're stuck with — it keeps
# the model's instructions honest ("you are searching the Security Handbook")
# and sidesteps the question of what a mid-conversation scope change means for
# the ten turns above it.
#
# The scope is stored as a *specification* — the same c[]/doc shape the search
# URL uses — and resolved fresh on every retrieval. See Retrieval::Scope for why
# freezing document ids here would be a bug rather than an optimisation.
class Conversation < ApplicationRecord
  belongs_to :user
  # Optional: the row can be nullified out from under a finished conversation
  # when an admin removes a model, and the transcript is still true.
  belongs_to :inference_model, optional: true

  has_many :messages, -> { order(:position) }, dependent: :destroy, inverse_of: :conversation

  validates :scope, exclusion: { in: [nil] }

  scope :for, ->(user) { where(user:) }
  scope :recent, -> { order(updated_at: :desc) }

  # nil means All — the same convention the wire format uses when it omits the
  # parameter. Built per call rather than memoized: a conversation object can
  # outlive a grant.
  def retrieval_scope = Retrieval::Scope.from_spec(scope, user:)

  # What to call this scope in the UI and in the model's instructions.
  def scope_label = retrieval_scope&.label || "your whole archive"

  # Whether this chat has an archive to draw on at all. A scope that names no
  # collection is a deliberate choice — chat with the model, leave the archive
  # out of it — so the model isn't handed a search tool that could only ever
  # come back empty. nil scope is All, which very much does search.
  def searches_archive? = !retrieval_scope&.names_nothing?

  def next_message_position = (messages.maximum(:position) || 0) + 1
end
