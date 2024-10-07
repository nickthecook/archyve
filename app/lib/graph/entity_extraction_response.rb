module Graph
  class EntityExtractionResponse
    # rubocop:disable Layout/LineLength
    #
    # ("entity"|"Minnie M. Baxter"|"organization"|"Minnie M. Baxter is a boat or organization, named in new and shining letters on it.")##
    # ("entity"|"Skippy"|"person"|"Skippy is the young boy who is wrestling with the tiller to keep the lumbering hulk (Minnie M. Baxter) head on.")##
    # ("location"|"Jersey Shore"|"geo"|"Jersey Shore is a location described as precipitous.")##
    # ("location"|"The great city"|"geo"|"The great city is a location with towering buildings and myriad windows across the river.")##
    # ("relationship"|"Man"|"Minnie M. Baxter"|"The man is the proud owner of Minnie M. Baxter.")##
    # ("relationship"|"Skippy"|"Minnie M. Baxter"|"Skippy is working on the Minnie M. Baxter, trying to keep it heading in the right direction."|8)|COMPLETE
    ENTITY_REGEX =
      /^#*\("(?'type'\w+)" \| "(?'name'[^"]+)" \| "(?'subtype'[^"]+)" \| "(?'desc'[^"]+)".*$/
    RELATIONSHIP_REGEX =
      /^#*\("(?'type'relationship)" \| "(?'from'[^"]+)" \| "(?'to'[^"]+)" \| "(?'desc'[^"]+)"(?: \| (?'strength'\d+))?.*$/
    # rubocop:enable Layout/LineLength

    def initialize(text)
      @text = text.strip
      @entity = false
      @relationship = false

      @match ||= detect_match
    end

    def match?
      @match.present?
    end

    def entity?
      @entity == true
    end

    def relationship?
      @relationship == true
    end

    def to_h
      @to_h ||= @match.names.zip(@match.captures).to_h.symbolize_keys
    end

    private

    def detect_match
      match = @text.match(RELATIONSHIP_REGEX)
      if match
        @relationship = true
      else
        match = @text.match(ENTITY_REGEX)
        if match
          @entity = true
        end
      end

      match
    end
  end
end
