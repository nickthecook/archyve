class ModelConfig < ApplicationRecord
  belongs_to :model_server
  has_many :messages, as: :author
end
