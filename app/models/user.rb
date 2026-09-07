class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # Deliberately :nullify, not :destroy. A source destroys its documents, so
  # cascading here would mean deleting a departing employee silently destroyed
  # every document they ever uploaded, along with its chunks and embeddings.
  has_many :sources, dependent: :nullify

  # Sign-in is by email, so identity has to be case- and whitespace-insensitive:
  # "Nick@Example.com " and "nick@example.com" are one account, not two. The
  # unique index is on the stored value, so normalizing before validation is
  # what makes that index mean what it looks like it means.
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # A capability *ceiling*, not a grant:
  #
  #   user     — chat and search, nothing to manage
  #   operator — + sources, collections, documents, filing
  #   admin    — + settings and user management, everywhere, no grant needed
  #
  # A per-object grant can raise you no higher than this, which is what makes
  # self-granting harmless — see #role_on.
  include Roleable

  validates :email_address, presence: true, uniqueness: true

  # The break-glass account is only break-glass while it exists and is still an
  # admin. Both guards live here rather than in a controller because they are
  # record invariants: no path — console, seed, future API — should be able to
  # lock everybody out of administration.
  validate :last_admin_keeps_their_role
  before_destroy :refuse_to_delete_the_last_admin

  # Effective role on one collection or source.
  #
  # The global role is a ceiling on the *kind* of thing you can do — chat,
  # content, the system — not a rung on the same ladder as the grant. So this is
  # a two-band rule, not `min`:
  #
  #   admin    — everything, everywhere, no grant needed
  #   operator — the grant exactly as written, up to and including admin *of
  #              that collection*. Managing a collection, its people included,
  #              is content ownership, which is precisely what an operator is
  #              for; a numeric min would cap them at operator and leave every
  #              access change waiting on a system admin.
  #   user     — read at most, whatever the grant says. Chat-only means
  #              chat-only, and a grant can't widen it.
  #
  # nil means no access at all. Deliberately not :user — a missing grant is
  # absence, not the weakest presence, and returning :user here would silently
  # hand every operator read access to every collection.
  def role_on(record)
    return :admin if admin?

    granted = record.granted_role_for(self)
    return nil if granted.nil?
    return :user if user?

    granted.to_sym
  end

  def may_on?(record, minimum)
    effective = role_on(record)
    return false if effective.nil?

    Roleable::ROLES.fetch(effective) >= Roleable::ROLES.fetch(minimum.to_sym)
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
