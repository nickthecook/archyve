class ModelConfig < ApplicationRecord
  belongs_to :model_server
  has_many :messages, as: :author

  scope :generation, -> { where(embedding: false) }
  scope :embedding, -> { where(embedding: true) }

  class << self
    def default_generation_model
      generation.find_by(default: true)
    end

    def default_embedding_model
      embedding.find_by(default: true)
    end
  end

  def description
    "#{name}@#{model_server.name}"
  end
end
