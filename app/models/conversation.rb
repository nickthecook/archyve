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
  belongs_to :agent
  # Optional: the row can be nullified out from under a finished conversation
  # when an admin removes a model, and the transcript is still true.
  belongs_to :inference_model, optional: true

  has_many :messages, -> { order(:position) }, dependent: :destroy, inverse_of: :conversation

  validates :scope, exclusion: { in: [nil] }

  scope :for, ->(user) { where(user:) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :answering, -> { where(id: Message.assistant.where(completed_at: nil).select(:conversation_id)) }

  def answering? = messages.assistant.exists?(completed_at: nil)

  # nil means All — the same convention the wire format uses when it omits the
  # parameter. Built per call rather than memoized: a conversation object can
  # outlive a grant.
  def retrieval_scope = Retrieval::Scope.from_spec(scope, user:)

  # What to call this scope in the UI and in the model's instructions.
  def scope_label = Retrieval::Corpus.for(self).label

  # Whether this chat has an archive to draw on at all. A scope that names no
  # collection is a deliberate choice — chat with the model, leave the archive
  # out of it — so the model isn't handed a search tool that could only ever
  # come back empty. nil scope is All, which very much does search. A fixed-set
  # agent has no picker, so its scope is never consulted.
  def searches_archive?
    return false unless agent.searches_archive?
    return true if agent.fixed_collections?

    !retrieval_scope&.names_nothing?
  end

  # Who it's with, and what it draws on when that's the archive: "Kevin · Handbook".
  def subject_label = [agent.name, (scope_label if agent.searches_archive?)].compact.join(" · ")

  def toolsets = agent.toolsets.map { it.new(self) }

  # Whether a citation here may link to the document: exactly what /documents/:id
  # lets this conversation's owner open. A fixed-set agent can cite documents they
  # can't, and the citation then renders as plain text.
  def reaches?(document_id)
    return true if user.admin?

    (@reaches ||= {}).fetch(document_id) do
      @reaches[document_id] = Document.reachable_by(user).exists?(document_id)
    end
  end

  def next_message_position = (messages.maximum(:position) || 0) + 1

  # The most recent turn a server reported a prompt size for.
  #
  # The context meter describes the conversation, but only a turn can have been
  # measured — and the window it was measured against belongs to the model that
  # answered *it*, which the person may since have switched away from. So the
  # turn carries both halves of the ratio and the meter reads them together.
  def last_measured_turn
    messages.assistant.where.not(input_tokens: nil).includes(:inference_model).last
  end
end
