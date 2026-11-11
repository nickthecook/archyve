module ApiCalls
  # Shrinks a recorded body to something a person can read in psql.
  #
  # Bodies land in jsonb when they parse and as a plain string when they don't,
  # which is what keeps a streamed chat response — an SSE event stream, not JSON
  # — readable instead of being lost to a parse error. jsonb holds a bare string
  # happily.
  module Body
    # Generous, because the strings being cut here are retrieved chunks and
    # model answers, and a body truncated mid-sentence answers fewer questions
    # than it raises.
    MAX_STRING = 10_000
    MAX_ITEMS = 50

    # The backstop for an unparseable body, which in practice means a streamed
    # response: large enough to hold a long answer's worth of SSE events.
    MAX_RAW = 256_000

    def self.summarize(raw)
      return nil if raw.blank?

      raw = as_utf8(raw) if raw.is_a?(String)
      shrink(JSON.parse(raw))
    rescue JSON::ParserError, TypeError
      truncate(raw.to_s, MAX_RAW)
    end

    def self.shrink(value)
      case value
      when Hash then value.transform_values { shrink(it) }
      when Array then shrink_array(value)
      when String then truncate(value, MAX_STRING)
      else value
      end
    end

    def self.shrink_array(array)
      return array.map { shrink(it) } if array.length <= MAX_ITEMS

      array.first(MAX_ITEMS).map { shrink(it) } << "[#{array.length - MAX_ITEMS} more items]"
    end

    def self.truncate(string, limit)
      return string if string.length <= limit

      "#{string[0, limit]}… [#{string.length} chars total]"
    end

    # Streamed chunks arrive as binary, which makes the whole buffer binary
    # once any of it isn't ASCII.
    def self.as_utf8(string)
      return string if string.encoding == Encoding::UTF_8 && string.valid_encoding?

      string.dup.force_encoding(Encoding::UTF_8).scrub
    end

    private_class_method :shrink_array, :truncate, :as_utf8
  end
end
