module Graph
  class CalculateMinContextSize
    AVG_CHARACTERS_PER_TOKEN = 4
    # TODO: this is also defined in documents_helper.rb; should be in one place
    DEFAULT_CHUNK_SIZE = 1000

    def execute
      return existing_calculation if existing_calculation

      Setting.set("kg_min_context_window_size", calculation)

      calculation
    end

    private

    def existing_calculation
      @existing_calculation ||= Setting.get("kg_min_context_window_size")
    end

    def calculation
      @calculation ||= (Prompts::ENTITY_EXTRACTION_PROMPT.size + DEFAULT_CHUNK_SIZE) / AVG_CHARACTERS_PER_TOKEN
    end
  end
end
