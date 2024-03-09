class ModelServer < ApplicationRecord
  has_many :model_configs

  enum provider: {
    ollama: 1,
    openai: 2
  }
end
