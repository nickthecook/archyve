module Chunkers
  class UnknownChunkingMethod < StandardError; end

  include Enumerable

  CHUNKING_METHODS = [
    { id: :recursive_split, name: "Recursive Split" },
    { id: :basic, name: "Basic" },
  ].freeze
end
