ENCRYPTION_KEYS_FILE = Rails.root.join("config/local/encryption_keys.json")

active_record_encryption_string = ENV.fetch("ACTIVE_RECORD_ENCRYPTION", nil)

active_record_encryption = if active_record_encryption_string.present?
  JSON.parse(ENV.fetch("ACTIVE_RECORD_ENCRYPTION", nil))
elsif File.exist?(ENCRYPTION_KEYS_FILE)
  JSON.parse(ENCRYPTION_KEYS_FILE.read)
else
  Rails.logger.warn("No encryption keys found, generating new ones in #{ENCRYPTION_KEYS_FILE}...")
  ENCRYPTION_KEYS_FILE.write(JSON.generate({
    primary_key: SecureRandom.base58(32),
    deterministic_key: SecureRandom.base58(32),
    key_derivation_salt: SecureRandom.base58(32),
  }))

  JSON.parse(ENCRYPTION_KEYS_FILE.read)
end

if active_record_encryption
  Rails.application.config.active_record.encryption.primary_key = active_record_encryption["primary_key"]
  Rails.application.config.active_record.encryption.deterministic_key = active_record_encryption["deterministic_key"]
  Rails.application.config.active_record.encryption.key_derivation_salt = active_record_encryption["key_derivation_salt"]
else
  $stderr.puts(
    <<~ERROR_MESSAGE
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      !! ERROR: Unable to find ActiveRecord encryption keys in
      !!  $ACTIVE_RECORD_ENCRYPTION or #{ENCRYPTION_KEYS_FILE}.
      !!
      !!  Please refer to the README for instructions on setting this variable.
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ERROR_MESSAGE
  )
end
