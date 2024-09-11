module Search
  class DistanceNormalizer
    MIN_DISTANCE = 0
    DISTANCE_RANGE = 1

    class NotAnEmbeddingModelError < StandardError; end

    def initialize(model_config)
      raise NotAnEmbeddingModelError unless model_config.embedding?

      @model_config = model_config
    end

    def normalize!(objects)
      objects.map do |object|
        object.distance = ((object.distance - min) / max * DISTANCE_RANGE) + MIN_DISTANCE
      end
    end

    private

    def max
      @max ||= @model_config.distance_max || max_for_provider
    end

    def min
      @min ||= @model_config.distance_min || min_for_provider
    end

    def model_server
      @model_server ||= @model_config.model_server || ModelServer.active_server
    end

    def max_for_provider
      case model_server.provider
      when "ollama"
        500.0
      when "openai", "openai_azure"
        2.0
      end
    end

    def min_for_provider
      case model_server.provider
      when "ollama"
        100.0
      when "openai", "openai_azure"
        0.0
      end
    end
  end
end
