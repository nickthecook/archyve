# frozen_string_literal: true

module Tools
  # A tool's payload as the text the model reads.
  #
  # RubyLLM passes a Hash return value through `Hash#to_s` — one line of Ruby
  # inspect syntax, every passage's markdown collapsed into `\n` escapes. The
  # headings and list markers that go missing there are what a model reads a
  # sequence of steps from, so passages are rendered as delimited blocks with
  # their newlines intact.
  #
  # Tools still return hashes, which is what their specs assert on; the render
  # happens at the Tools::Base#call seam.
  class Reply
    # Rendered as blocks rather than as a field. Every other key is a fact
    # about the call and reads as a line.
    PASSAGES = :passages

    # The sentence the model is meant to act on goes last, nearest what it
    # writes next.
    INSTRUCTION = :instruction

    def self.call(payload)
      payload.is_a?(Hash) ? new(payload).to_s : payload
    end

    def initialize(payload)
      @payload = payload
    end

    def to_s
      [facts, *passages, @payload[INSTRUCTION]].compact_blank.join("\n\n")
    end

    private

    def facts
      @payload.except(PASSAGES, INSTRUCTION).filter_map { |key, value| fact(key, value) }.join("\n")
    end

    def fact(key, value)
      case value
      when Hash then "#{key}: #{span(value)}"
      when Array then rows(key, value)
      else "#{key}: #{value}"
      end
    end

    # The {from:, to:, total:} shape both reads and listings page with.
    def span(hash)
      return hash.map { |key, value| "#{key} #{value}" }.join(", ") unless hash.key?(:total)

      hash[:from] ? "#{hash[:from]}–#{hash[:to]} of #{hash[:total]}" : "#{hash[:total]} total"
    end

    # Listing entries: one row per line, since there is no prose in them to
    # preserve.
    def rows(key, entries)
      return if entries.empty?

      ["#{key}:", *entries.map { "  #{row(it)}" }].join("\n")
    end

    def row(entry)
      entry.map { |field, value| "#{field}: #{Array(value).join(', ')}" }.join(" · ")
    end

    def passages
      Array(@payload[PASSAGES]).map { passage(it) }
    end

    def passage(hit)
      ["--- [#{hit[:handle]}] #{named(hit)}".rstrip, locator(hit), "", hit[:text]].compact.join("\n")
    end

    def named(hit)
      [hit[:document], hit[:section]].compact_blank.join(" · ")
    end

    def locator(hit)
      parts = [chunk_of(hit), ("document id #{hit[:id]}" if hit[:id])].compact
      "    #{parts.join(' · ')}" if parts.any?
    end

    def chunk_of(hit)
      return if hit[:chunk].nil?

      hit[:chunks] ? "chunk #{hit[:chunk]} of #{hit[:chunks]}" : "chunk #{hit[:chunk]}"
    end
  end
end
