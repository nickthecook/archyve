module ApiCalls
  module Headers
    REDACTED = "[REDACTED]".freeze
    SECRET = /\A(?:authorization|cookie|set-cookie|x-api-key|api-key)\z/i

    def self.redact(headers)
      headers.to_h.to_h { |name, value| [name, name.to_s.match?(SECRET) ? REDACTED : value] }
    end
  end
end
