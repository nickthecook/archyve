class ModelServer < ApplicationRecord
  scope :active, -> { where(active: true) }

  enum provider: {
    ollama: 1,
    openai: 2,
  }

  class << self
    def active_server
      last.make_active if active.empty? && last.present?

      ModelServer.active.first
    end
  end

  def make_active
    active_servers = ModelServer.active
    return if active_servers.length == 1 && active_servers.first == self

    active_servers.update(active: false)
    update!(active: true)
  end
end
