module Chunkers
  class UnknownChunkingMethod < StandardError; end

  include Enumerable

  module InputType
    PLAIN_TEXT = 0
    COMMON_MARK = 1
  end

  CHUNKING_METHODS = [
    { id: :recursive_split, name: "Recursive Split" },
    { id: :basic, name: "Basic" },
  ].freeze

  def self.chunker_for(chunking_profile)
    chunking_method = chunking_profile.method
    chunker_class = case chunking_method.to_sym
    when :basic
      Chunkers::BasicCharacterChunker
    when :recursive_split
      Chunkers::RecursiveTextChunker
    else
      raise UnknownChunkingMethod,
        "Unknown chunking method '#{chunking_method}"
    end
    chunker_class.new(chunking_profile)
  end
end
