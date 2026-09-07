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

  validates :email_address, presence: true, uniqueness: true

  def to_s = email_address
end
