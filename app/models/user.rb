class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # Sign-in is by email, so identity has to be case- and whitespace-insensitive:
  # "Nick@Example.com " and "nick@example.com" are one account, not two. The
  # unique index is on the stored value, so normalizing before validation is
  # what makes that index mean what it looks like it means.
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  def to_s = email_address
end
