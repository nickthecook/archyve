module Search
  class SearchHit
    attr_reader :chunk, :distance, :previous_distance
    attr_accessor :relevant

    def initialize(chunk, distance, previous_distance = nil)
      @chunk = chunk
      @distance = distance
      @previous_distance = previous_distance
    end

    def collection
      @chunk.collection
    end

    def document
      @chunk.document
    end

    def distance_increase_ratio
      return 0 if @previous_distance.nil?

      (@distance - @previous_distance) / @previous_distance
    end
  end
end
