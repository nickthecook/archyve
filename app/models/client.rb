class Client < ApplicationRecord
  API_KEY_LENGTH = 48
  API_KEY_LENGTH_CHARACTERS = 64

  encrypts :api_key

  belongs_to :user

  validate :api_key_format
  validates :name, uniqueness: true

  class << self
    def new_client_id
      SecureRandom.uuid
    end

    def new_api_key
      SecureRandom.base64(API_KEY_LENGTH)
    end
  end

  def collections
    # TODO: scope to Client
    Collection.all
  end

  private

  def api_key_format
    errors.add(:api_key, "is required") if api_key.blank?

    unless api_key.length == API_KEY_LENGTH_CHARACTERS
      errors.add(:api_key, "must be exactly #{API_KEY_LENGTH_CHARACTERS} base64 characters")
    end

    begin
      errors.add(:api_key, "must be a valid base64 string") unless Base64.strict_decode64(api_key)
    rescue StandardError
      false
    end
  end
end
