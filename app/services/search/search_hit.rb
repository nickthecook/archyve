module Search
  class SearchHit
    attr_reader :chunk, :distance

    def initialize(chunk, distance)
      @chunk = chunk
      @distance = distance
    end

    def collection
      @chunk.collection
    end

    def document
      @chunk.document
    end
  end
end
