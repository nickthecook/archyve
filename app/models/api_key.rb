class ApiKey < ApplicationRecord
  PREFIX = "archyve_".freeze

  # Recognisable by secret scanners, and enough to tell a person's keys apart
  # without being enough to use one.
  VISIBLE_LENGTH = PREFIX.length + 6

  # A key is never re-checked against Keycloak, so a revoked SSO user keeps
  # working until someone deletes their keys. Owners who haven't signed in for
  # this long are flagged on the admin list for that reason.
  DORMANT_AFTER = 30.days

  # Every authenticated request would otherwise be a write.
  USE_RECORDED_EVERY = 1.minute

  belongs_to :user

  validates :name, presence: true

  before_validation :issue_token, on: :create

  # The plaintext token, only on the instance that created it. Nothing stores it.
  attr_reader :token

  scope :recent, -> { order(created_at: :desc) }

  def self.authenticate(token)
    return if token.blank? || !token.start_with?(PREFIX)

    find_by(token_digest: digest(token))
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token)

  # Whoever acts with this key. A user today; a service account later.
  def principal = user

  def owner_dormant? = user.last_signed_in_at.nil? || user.last_signed_in_at < DORMANT_AFTER.ago

  def used!
    return if last_used_at&.after?(USE_RECORDED_EVERY.ago)

    update_column(:last_used_at, Time.current)
  end

  private

  def issue_token
    @token = PREFIX + SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@token)
    self.token_prefix = @token.first(VISIBLE_LENGTH)
  end
end
