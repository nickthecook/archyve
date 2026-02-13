module Parsers
  class Fact < Base
    def chunks
      [Chunkers::ChunkRecord.new(excerpt: text)]
    end
  end
end
