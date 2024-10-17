module Parsers
  class Image < Base
    def chunks
      Chunkers.single_chunk(self)
    end
  end
end
