# One model Archyve may use, on one server.
#
# Named for inference rather than language because `kind` is expected to grow:
# vision, audio and rerank models are the same kind of record, differing only in
# what they are asked to do.
#
# ## What lives here, and what doesn't
#
# A row holds identity (the id the provider knows it by), connection (which
# server to reach it through) and capability (dimensions, context window, tools).
# It does not hold inference *semantics* — nomic's search_document:/search_query:
# prefixes stay in Embeddings::Embed, because they are behaviour, not
# configuration, and a row that carried them would invite the idea that a new
# embedding model is only ever a new row.
class InferenceModel < ApplicationRecord
  belongs_to :inference_server

  # Not ordered, unlike Roleable's roles, so a plain enum rather than a shared
  # concern. New kinds append; the integers are stored.
  enum :kind, { chat: 0, embedding: 1 }, validate: true

  validates :name, presence: true, uniqueness: { scope: :inference_server_id }
  validates :dimensions, presence: true, if: :embedding?
  validates :context_window, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  validate :dimensions_must_match_the_column, if: -> { embedding? && dimensions.present? }
  validate :only_chat_models_are_preferred
  validate :only_one_embedding_model
  validate :corpus_must_be_empty, on: :create, if: :embedding?

  before_save :demote_the_incumbent, if: -> { chat? && preferred? && will_save_change_to_preferred? }

  scope :usable, -> { where(enabled: true) }

  # Chat models that can actually do the job. Archyve's retrieval is a tool the
  # model calls, not context stuffed into the prompt — a model that can't call
  # tools can't decide *whether* to search or *what* to search for, which is the
  # part worth having. So this is the set chat may offer, not a preference.
  scope :for_chat, -> { usable.chat.where(supports_tools: true) }
  # The list a picker offers. Named separately from `for_chat` because the two
  # surfaces that ask a question — the chat composer and the landing bar — have
  # to offer the same models in the same order, and that is easy to let drift
  # when each builds its own chain.
  scope :choosable_for_chat, -> { for_chat.includes(:inference_server).order(:name) }

  # The corpus's embedding model, or nil.
  #
  # Returns nil rather than raising because "nothing is configured yet" is a
  # real state of a fresh install, not an error — nothing is seeded unless
  # OLLAMA_API_BASE is set. Callers decide what to do about it; Embeddings::Embed
  # raises, the search page explains, the settings page offers to fix it.
  def self.active_embedding
    usable.embedding.first
  end

  # The chat model a new conversation gets, or nil. `preferred` wins; failing
  # that, any tool-capable chat model, so a fresh install with one imported
  # model works without anyone visiting Settings to anoint it.
  def self.default_chat = for_chat.order(preferred: :desc, id: :asc).first

  def label = display_name.presence || name

  private

  # The embeddings.embedding column is a vector(768) with one cosine HNSW index.
  # A model of any other width cannot physically be stored in it, so it can
  # never be this corpus's embedder — better to say so on the form than to fail
  # on the first document somebody uploads.
  def dimensions_must_match_the_column
    return if dimensions == Embedding::DIMENSIONS

    errors.add(
      :dimensions,
      "must be #{Embedding::DIMENSIONS} — the embeddings column is a vector(#{Embedding::DIMENSIONS}), " \
      "so a #{dimensions}-dimension model can't be stored in it"
    )
  end

  def demote_the_incumbent
    self.class.chat.where(preferred: true).where.not(id:).update_all(preferred: false)
  end

  def only_chat_models_are_preferred
    errors.add(:preferred, "only applies to chat models") if preferred? && !chat?
  end

  def only_one_embedding_model
    return unless embedding?

    others = self.class.embedding.where.not(id: id)
    errors.add(:kind, "can only be embedding for one model — #{others.first&.name} already is") if others.exists?
  end

  # The freeze. Embeddings from different models are not comparable, so adopting
  # a *different* embedder strands every vector already stored: search keeps
  # running and keeps returning nothing useful, which is the worst kind of
  # broken.
  #
  # The guard is the existence of vectors rather than a flag, because that is
  # what actually makes the change dangerous — with an empty corpus there is
  # nothing to strand and this is simply a setup step.
  #
  # And it counts only vectors some *other* model produced. Declaring the
  # embedder the corpus is already full of is not a change at all; it is what an
  # install that predates these rows has to do to describe itself, and what the
  # seeds do on an archive that has been embedding happily all along.
  #
  # docs/architecture.md calls re-embedding a first-class job. When that exists,
  # this is where it gets offered instead of refused.
  def corpus_must_be_empty
    stranded = Embedding.where.not(embedding_model: name)
    return unless stranded.exists?

    errors.add(
      :base,
      "#{stranded.count} chunks are already embedded with #{stranded.first.embedding_model}. Changing the " \
      "embedding model means re-embedding the whole archive, which Archyve can't do yet."
    )
  end
end
