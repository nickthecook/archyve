class ModelServer < ApplicationRecord
  has_many :model_configs, dependent: :destroy

  scope :active, -> { where(active: true) }

  enum provider: {
    ollama: 1,
    openai: 2,
  }

  def make_active
    active_servers = ModelServer.active
    return if active_servers.length == 1 && active_servers.first == self

    active_servers.update(active: false)
    update!(active: true)
  end
end
