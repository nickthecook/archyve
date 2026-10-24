require "securerandom"
require "yaml"

module Archyve
  # Secrets the app can make for itself. The environment wins; otherwise they
  # come from a key file, generated on first boot.
  class Keys
    GENERATORS = {
      "SECRET_KEY_BASE" => -> { SecureRandom.hex(64) },
      "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => -> { SecureRandom.alphanumeric(32) },
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => -> { SecureRandom.alphanumeric(32) },
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => -> { SecureRandom.alphanumeric(32) }
    }.freeze

    ENCRYPTION = {
      primary_key: "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
      deterministic_key: "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY",
      key_derivation_salt: "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"
    }.freeze

    def initialize(path, env: ENV)
      @path = Pathname(path)
      @env = env
    end

    def [](name)
      @env[name].presence || stored.fetch(name)
    end

    private

    def stored
      @stored ||= read || create
    end

    def read
      YAML.safe_load_file(@path) if @path.exist?
    end

    # Web and jobs boot together, so creation must have exactly one winner: the
    # link fails if the file exists, and a reader never sees it half-written.
    def create
      draft = @path.sub_ext(".#{SecureRandom.hex(4)}.tmp")
      draft.write(GENERATORS.transform_values(&:call).to_yaml, perm: 0o600)
      File.link(draft, @path)
      read
    rescue Errno::EEXIST
      read
    rescue SystemCallError => e
      raise "No key file at #{@path}, and couldn't create one (#{e.message}). " \
            "Mount a writable volume there, or set #{GENERATORS.keys.join(', ')}."
    ensure
      draft&.delete if draft&.exist?
    end
  end
end
