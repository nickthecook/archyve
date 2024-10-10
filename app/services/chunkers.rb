module Chunkers
  class UnknownChunkingMethod < StandardError; end

  include Enumerable

  module InputType
    PLAIN_TEXT = 0
    COMMON_MARK = 1
    HTML = 2
    IMAGE_JPG = 3
  end

  CHUNKING_METHODS = [
    { id: :recursive_split, name: "Recursive Split" },
    { id: :basic, name: "Basic" },
  ].freeze

  def self.chunker_for(chunking_profile, text_type)
    chunking_method = chunking_profile.method.to_sym
    if chunking_method == :bytes
      # Mapping :bytes method for backwards compatibility since
      # the DB will have existing chunking profiles that we might want to "reprocess"
      Rails.logger.info("Backwards compatibility - mapping :bytes to :recursive_split chuking method")
      chunking_method = :recursive_split
    end
    chunker_class = case chunking_method
    when :basic
      Chunkers::BasicCharacterChunker
    when :recursive_split
      Chunkers::RecursiveTextChunker
    else
      raise UnknownChunkingMethod,
        "Unknown chunking method '#{chunking_method}"
    end
    chunker_class.new(chunking_profile, text_type)
  end
end
