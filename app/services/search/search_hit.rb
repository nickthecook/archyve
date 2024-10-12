module Search
  class SearchHit
    attr_reader :reference
    attr_accessor :distance, :relevant, :previous_distance

    def initialize(reference, distance, previous_distance = nil)
      @reference = reference
      @distance = distance
      @previous_distance = previous_distance
    end

    def collection
      @reference.collection
    end

    def document
      @reference.document if @reference.respond_to?(:document)
    end

    def name
      return "#{@reference.name} (#{@reference.entity_type})" if @reference.respond_to?(:name)

      "#{@reference.class.name} #{@reference.id}"
    end

    def content
      return @reference.content if @reference.respond_to?(:content)

      @reference.summary if @reference.respond_to?(:summary)
    end

    def distance_increase_ratio
      return 0 if @previous_distance.nil?

      (@distance - @previous_distance) / @previous_distance
    end

    # (i.e., if we always use document.link and document.created_at)
    #
    # def link
    #   @reference.link if @reference.respond_to?(:link)
    # end

    # def created_at
    #   @reference.created_at if @reference.respond_to?(:created_at)
    # end

    # def filename
    #   @referemce.filename if @reference.respond_to?(:filename)
    # end
  end
end
