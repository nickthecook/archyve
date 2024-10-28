class ModelConfig < ApplicationRecord
  class ModelTypeError < StandardError; end

  has_many :messages, as: :author, dependent: :destroy
  belongs_to :model_server, optional: true

  scope :generation, -> { where(embedding: false).where(vision: false) }
  scope :embedding, -> { where(embedding: true) }
  scope :vision, -> { where(vision: true).where(embedding: false) }

  validate :model_type_flags_are_ok

  # Require API version if ...
  validates :api_version, presence: true, if: :api_version_required?

  def api_version_required?
    model_server&.api_version_required?
  end

  def context_window_size
    self[:context_window_size] || active_server.default_context_window_size
  end

  def make_active_embedding_model
    raise ModelTypeError, "Model is not an embedding model" unless embedding?

    Setting.set("embedding_model", id)
  end

  def make_default_chat_model
    raise ModelTypeError, "Model is an embedding model" if embedding?

    Setting.set("chat_model", id)
  end

  def make_active_summarization_model
    raise ModelTypeError, "Model is an embedding model" if embedding?

    Setting.set("summarization_model", id)
  end

  def make_active_vision_model
    raise ModelTypeError, "Model is not a vision model" unless vision?

    Setting.set("vision_model", id)
  end

  def make_active_entity_extraction_model
    raise ModelTypeError, "Model is an embedding model" if embedding?

    Setting.set("entity_extraction_model", id)
  end

  private

  def active_server
    model_server || ModelServer.active_server
  end

  def model_type_flags_are_ok
    return unless vision? && embedding?

    errors.add(:embedding, "An embedding model cannot also be a vision model")
    errors.add(:vision, "A vision model cannot also be an embedding model")
  end
end
