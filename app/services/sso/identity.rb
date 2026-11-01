# Turns verified ID token claims into the User they refer to.
#
# Authentication only: everyone arrives as a :visitor with no grants, and an
# admin raises them from Settings. The group check below is a gate on signing in
# at all, not a mapping onto Archyve's roles.
class Sso::Identity
  class Refused < Sso::Error; end

  def initialize(claims)
    @claims = claims
  end

  def user
    refuse_unless_entitled

    found = by_subject || linked_by_email || build
    found.email_address = email
    refuse_if_email_belongs_to_somebody_else(found)
    found.save!
    found
  end

  private

  attr_reader :claims

  def subject = claims["sub"]
  def email = claims["email"]
  def email_verified? = claims["email_verified"] == true
  def groups = Array(claims["groups"])

  def entitled? = groups.include?(Sso.required_group)

  # Revoking the group in Keycloak has to reach a browser that is already signed
  # in, and sessions here outlive any single request — so the refusal takes their
  # existing ones, and their API keys, with it rather than only blocking the next
  # sign-in.
  def refuse_unless_entitled
    return if entitled?

    by_subject&.sessions&.destroy_all
    by_subject&.api_keys&.destroy_all
    raise Refused, "Your account doesn't have access to Archyve."
  end

  # Reached when the IdP asserts an address that is already somebody's here but
  # we weren't allowed to link on it — an unverified claim, or a rename onto an
  # address in use. The unique index would raise; saying so is more useful.
  def refuse_if_email_belongs_to_somebody_else(found)
    return if email.blank?
    return unless User.where(email_address: email).where.not(id: found.id).exists?

    raise Refused, "An Archyve account already uses that email address. Ask an admin to link it."
  end

  def by_subject
    return if subject.blank?

    @by_subject ||= User.find_by(sso_subject: subject, sso_issuer: Sso.issuer)
  end

  # The one-time link, and the only moment email decides anything. Unverified
  # addresses are refused because inheriting an existing account — the seeded
  # admin's, say — should cost more than setting an attribute at the IdP.
  def linked_by_email
    return unless email_verified? && email.present?

    User.find_by(email_address: email)&.tap do |user|
      user.sso_subject = subject
      user.sso_issuer = Sso.issuer
    end
  end

  def build
    User.new(sso_subject: subject, sso_issuer: Sso.issuer, role: :visitor)
  end
end
