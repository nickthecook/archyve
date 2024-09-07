class ModelServer < ApplicationRecord
  encrypts :api_key

  scope :active, -> { where(active: true) }

  enum :provider, {
    ollama: 1,
    openai_azure: 2,
    openai: 3,
  }, prefix: :provider

  # Require API key if ...
  validates :api_key, presence: true, if: :api_key_required?

  # Return true for providers that require an API key
  def api_key_required?
    provider_openai_azure?
  end

  # Return true for providers that require models to include an API version
  def api_version_required?
    provider_openai_azure?
  end

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
