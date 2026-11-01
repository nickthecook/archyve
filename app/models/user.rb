class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  # Deliberately :nullify, not :destroy. A source destroys its documents, so
  # cascading here would mean deleting a departing employee silently destroyed
  # every document they ever uploaded, along with its chunks and embeddings.
  has_many :sources, dependent: :nullify

  # :destroy, unlike sources above, because the opposite reasoning applies. A
  # conversation is personal correspondence with the archive, not content the
  # archive holds — nobody else can read it, so nothing survives its author.
  has_many :conversations, dependent: :destroy

  # Sign-in is by email, so identity has to be case- and whitespace-insensitive:
  # "Nick@Example.com " and "nick@example.com" are one account, not two. The
  # unique index is on the stored value, so normalizing before validation is
  # what makes that index mean what it looks like it means.
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # A capability *ceiling*, not a grant:
  #
  #   visitor  — chat and search, nothing to manage
  #   curator  — + sources, collections, documents, filing
  #   admin    — + settings and user management, everywhere, no grant needed
  #
  # A per-object grant can raise you no higher than this, which is what makes
  # self-granting harmless — see #grant_on.
  include Roleable

  validates :email_address, presence: true, uniqueness: true

  # The break-glass account is only break-glass while it exists and is still an
  # admin. Both guards live here rather than in a controller because they are
  # record invariants: no path — console, seed, future API — should be able to
  # lock everybody out of administration.
  validate :last_admin_keeps_their_role
  before_destroy :refuse_to_delete_the_last_admin

  def sso? = sso_subject.present?

  # An SSO user has no password, so has_secure_password's presence check has to
  # stand down for them. Deliberately narrow: `validations: false` would drop
  # all four of its validations, taking with it the confirmation check the
  # account page depends on and the blank check that stops an admin creating an
  # account nobody can ever sign in to.
  def errors
    super.tap { |errors| errors.delete(:password, :blank) if sso? }
  end

  # Effective grant on one collection or source, with the global role as a
  # ceiling on the *kind* of thing you can do — chat, content, the system:
  #
  #   admin    — manager, everywhere, no grant needed
  #   curator  — the grant exactly as written, up to and including manager
  #   visitor  — accessor at most, whatever the grant says. Chat-only means
  #              chat-only, and a grant can't widen it.
  #
  # nil means no access at all. Deliberately not :accessor — a missing grant is
  # absence, not the weakest presence, and returning :accessor here would
  # silently hand every curator read access to every collection.
  def grant_on(record)
    return :manager if admin?

    granted = record.granted_access_for(self)
    return nil if granted.nil?
    return :accessor if visitor?

    granted.to_sym
  end

  def may_on?(record, minimum)
    effective = grant_on(record)
    return false if effective.nil?

    Grantable::ACCESS.fetch(effective) >= Grantable::ACCESS.fetch(minimum.to_sym)
  end

  private

  def other_admins?
    self.class.admin.where.not(id: id).exists?
  end

  def last_admin_keeps_their_role
    return unless persisted? && role_changed?(from: "admin")
    return if other_admins?

    errors.add(:role, "can't change: this is the only admin left")
  end

  def refuse_to_delete_the_last_admin
    return unless admin?
    return if other_admins?

    errors.add(:base, "The only admin can't be deleted.")
    throw(:abort)
  end

  def to_s = email_address
end
