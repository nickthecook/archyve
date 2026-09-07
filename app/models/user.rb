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

  # A capability *ceiling*, not a grant. Ordered smallest to largest so
  # `at_least?` is a comparison and so the per-collection and per-source grants
  # coming later can be combined with `min` — a grant can raise you no higher
  # than your role, which is what makes self-granting harmless.
  #
  #   user     — chat and search, nothing to manage
  #   operator — + sources, collections, documents, filing
  #   admin    — + settings and user management, everywhere, no grant needed
  enum :role, { user: 0, operator: 1, admin: 2 }, default: :user, validate: true

  validates :email_address, presence: true, uniqueness: true

  # The break-glass account is only break-glass while it exists and is still an
  # admin. Both guards live here rather than in a controller because they are
  # record invariants: no path — console, seed, future API — should be able to
  # lock everybody out of administration.
  validate :last_admin_keeps_their_role
  before_destroy :refuse_to_delete_the_last_admin

  # Roles are ordered, so "may they do operator things?" is `>=`, never a list
  # of equality checks that has to be revisited every time a role is added.
  def at_least?(minimum)
    self.class.roles.fetch(role) >= self.class.roles.fetch(minimum.to_s)
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
