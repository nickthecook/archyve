class ModelConfig < ApplicationRecord
  class ModelTypeError < StandardError; end

  has_many :messages, as: :author, dependent: :destroy
  belongs_to :model_server, optional: true

  scope :generation, -> { where(embedding: false) }
  scope :embedding, -> { where(embedding: true) }
  scope :default, -> { where(default: true) }

  # Require API version if ...
  validates :api_version, presence: true, if: :api_version_required?

  def api_version_required?
    model_server&.api_version_required?
  end

  def context_window_size
    self[:context_window_size] || model_server.default_context_window_size
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

  def make_active_entity_extraction_model
    raise ModelTypeError, "Model is an embedding model" if embedding?

    Setting.set("entity_extraction_model", id)
  end
end
