class ModelConfig < ApplicationRecord
  belongs_to :model_server
  has_many :messages, as: :author

  def description
    "#{name}@#{model_server.name}"
  end
end
