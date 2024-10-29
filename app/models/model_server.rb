class ModelServer < ApplicationRecord
  encrypts :api_key

  scope :active, -> { where(active: true) }

  include Turbo::Broadcastable

  after_update_commit lambda {
    broadcast_replace_to(
      "settings",
      target: "settings_model_servers",
      partial: "settings/model_servers",
      locals: { model_server: ModelServer.new }
    )
  }

  enum :provider, {
    ollama: 1,
    openai_azure: 2,
    openai: 3,
  }, prefix: :provider

  # Require API key if ...
  validates :api_key, presence: true, if: :api_key_required?

  validates :provider, presence: true
  validates :name, presence: true
  validates :url, presence: true

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

  def default_context_window_size
    if provider_openai_azure?
      # May be more per model, but we can assume a bigger default
      8 * 1024
    elsif provider_openai?
      # May be more per model, but we can assume a bigger default
      16 * 1024
    else
      # The default for ollama unless overridden by custom Modelfile
      2 * 1024
    end
  end

  def make_active
    active_servers = ModelServer.active
    return if active_servers.length == 1 && active_servers.first == self

    active_servers.update(active: false)
    update!(active: true)
  end

  # soft deletion: move to concern when adding the second one
  scope :deleted, -> { with_deleted.where.not(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  default_scope { where(deleted_at: nil) }

  def mark_as_deleted
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end
end
