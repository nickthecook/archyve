class Session < ApplicationRecord
  # Absolute, not sliding. Revoking someone's Keycloak group only reaches a
  # browser that is already signed in when their session runs out, so this is
  # the upper bound on how long a revoked user keeps working. A constant rather
  # than a Setting: that bound shouldn't be wideable from a signed-in browser.
  LIFETIME = 1.day

  belongs_to :user

  # Encrypted because it is a bearer token carrying the user's claims. Its
  # presence is also what marks this session as SSO-authenticated, which is how
  # sign-out knows whether to detour via Keycloak.
  encrypts :sso_id_token

  scope :active, -> { where(created_at: LIFETIME.ago..) }
  scope :expired, -> { where(created_at: ...LIFETIME.ago) }

  def sso? = sso_id_token.present?
end
