# STI base class. Concrete endpoints live in app/models/endpoints/*, and each
# implements #auth_headers and #access!. See docs/architecture.md.
class Endpoint < ApplicationRecord
  MissingImplementationError = Class.new(StandardError)

  TYPES = %w[Endpoints::Bookstack Endpoints::Web].freeze

  ACCESS_ERROR_LIMIT = 500
  DEFAULT_TIMEOUT = 30

  has_many :sources, dependent: :restrict_with_error

  # Encryption wraps the serialized value, so this order is load-bearing.
  serialize :credentials, coder: JSON
  encrypts :credentials

  store_accessor :config, :base_url

  validates :name, presence: true, uniqueness: true
  before_validation :normalize_base_url
  validate :base_url_must_be_an_http_url, if: -> { base_url.present? }

  def self.description = ""
  def self.types = TYPES.map(&:constantize)
  def self.permitted_keys = [:name, :base_url]

  # Accessors for keys in the encrypted `credentials` hash. Not store_accessor:
  # it decorates the same attribute `encrypts` does, and which wins depends on
  # declaration order.
  def self.credential(*names)
    names.each do |name|
      key = name.to_s

      define_method(key) { credentials[key] }
      define_method("#{key}=") { |value| store_credential(key, value) }
    end
  end

  def type_label = self.class.type_label

  def credentials = super || {}

  def clear_credential(name)
    self.credentials = credentials.except(name.to_s)
  end

  def accessible? = accessed_at.present? && access_error.blank?

  def access
    access!
    update!(accessed_at: Time.current, access_error: nil)
    true
  rescue StandardError => e
    Rails.logger.error("endpoint #{id} access failed: #{e.class}: #{e.message}")
    update!(accessed_at: Time.current, access_error: "#{e.class}: #{e.message}".truncate(ACCESS_ERROR_LIMIT))
    false
  end

  # Named `client` because Active Record has its own `connection`.
  def client(timeout: DEFAULT_TIMEOUT, raise_errors: true)
    Http.connection(base_url, timeout: timeout, raise_errors: raise_errors).tap do |connection|
      auth_headers.each { |header, value| connection.headers[header] = value }
    end
  end

  def auth_headers
    raise MissingImplementationError, "#{self.class.name} must implement #auth_headers"
  end

  def access!
    raise MissingImplementationError, "#{self.class.name} must implement #access!"
  end

  private

  # Blank is "unchanged", as with has_secure_password: an edit form renders a
  # secret as an empty field, and saving it must not wipe the stored one.
  # Assigns a new hash so Active Record sees the change.
  def store_credential(key, value)
    value = value.to_s.strip
    return if value.blank?

    self.credentials = credentials.merge(key => value)
  end

  def normalize_base_url
    return if base_url.blank?

    self.base_url = base_url.strip.sub(%r{/+\z}, "")
  end

  def base_url_must_be_an_http_url
    uri = URI.parse(base_url)
    raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:base_url, "must be an http:// or https:// address")
  end
end
